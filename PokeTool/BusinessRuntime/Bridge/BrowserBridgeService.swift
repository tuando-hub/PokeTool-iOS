import Foundation

@MainActor
final class BrowserBridgeService {
    static let apiVersion = "1.0.0"

    private let browserManager: BrowserManager
    private let codec: BridgeValueCodec
    private let limits: BrowserBridgeLimits
    private var ownedBrowsers: Set<BrowserID> = []

    init(
        browserManager: BrowserManager,
        codec: BridgeValueCodec = BridgeValueCodec(),
        limits: BrowserBridgeLimits = BrowserBridgeLimits()
    ) {
        self.browserManager = browserManager
        self.codec = codec
        self.limits = limits
    }

    var pendingLimit: Int { limits.maximumPendingOperations }

    func perform(method: String, payloadJSON: String) async throws -> String {
        guard payloadJSON.utf8.count <= limits.maximumPayloadBytes else {
            throw BridgeArgumentError(method: method, argument: "payload", expected: "payload <= 2 MB", received: "oversized")
        }
        let payload = try decodePayload(payloadJSON, method: method)
        let args = payload.objectValue?["args"]?.arrayValue ?? []

        switch method {
        case "__delay":
            guard let value = args.first, case .number(let milliseconds) = value,
                  milliseconds.isFinite, milliseconds >= 0,
                  milliseconds <= limits.maximumTimeout * 1_000 else {
                throw BridgeArgumentError(
                    method: "delay", argument: "ms",
                    expected: "finite number from 0 through 120000", received: "invalid"
                )
            }
            try await Task.sleep(for: .milliseconds(milliseconds))
            return "null"

        case "create":
            let options: BrowserCreateOptions? = try optional(args, 0, method: method)
            let attributes = options?.metadata ?? [:]
            guard attributes.count <= limits.maximumMetadataEntries else {
                throw BridgeArgumentError(method: method, argument: "metadata", expected: "<= 32 entries", received: "oversized")
            }
            let configuration = BrowserSessionConfiguration(
                metadata: BrowserMetadata(
                    purpose: .runtime, label: "JavaScript Runtime",
                    ownerID: nil, attributes: attributes
                ),
                userAgent: options?.userAgent.map(UserAgentSelection.custom) ?? .systemDefault,
                dataStorePolicy: options?.persistence == "sharedPersistent" ? .shared : .isolated,
                viewport: .zero
            )
            let id = try browserManager.createSession(configuration: configuration)
            ownedBrowsers.insert(id)
            return try codec.encode(id.description)

        case "destroy":
            let id = try browserID(args, method)
            try await browserManager.destroySession(id)
            ownedBrowsers.remove(id)
            return "null"

        case "load":
            let id = try browserID(args, method)
            let input: BrowserLoadRequest = try required(args, 1, name: "request", method: method)
            try await browserManager.load(try makeRequest(input, method: method), in: id)
            return "null"

        case "reload", "reloadFromOrigin":
            let id = try browserID(args, method)
            try await browserManager.reload(id, fromOrigin: method == "reloadFromOrigin")
            return "null"

        case "stop":
            try browserManager.stopLoading(try browserID(args, method)); return "null"
        case "back":
            try browserManager.goBack(try browserID(args, method)); return "null"
        case "forward":
            try browserManager.goForward(try browserID(args, method)); return "null"

        case "evaluate":
            let id = try browserID(args, method)
            let source: String = try required(args, 1, name: "source", method: method)
            guard source.count <= limits.maximumSourceLength else {
                throw BridgeArgumentError(method: method, argument: "source", expected: "<= 1,000,000 characters", received: "oversized string")
            }
            let options: BrowserTimeoutOptions? = try optional(args, 2, method: method)
            let value = try await browserManager.evaluateJavaScript(
                source, in: id, timeout: try timeout(options?.timeoutMs, method: method)
            )
            return try codec.encodeJSON(value.bridgeJSONValue)

        case "snapshot":
            return try codec.encodeJSON(snapshotValue(try browserManager.snapshot(for: browserID(args, method))))
        case "url":
            return try codec.encode(try browserManager.snapshot(for: browserID(args, method)).navigation.currentURL?.absoluteString)
        case "title":
            return try codec.encode(try browserManager.snapshot(for: browserID(args, method)).navigation.title)
        case "readyState":
            return try codec.encode(try await browserManager.pageReadyState(in: browserID(args, method)))
        case "html":
            let html = try await browserManager.pageHTML(in: browserID(args, method))
            guard html.count <= limits.maximumHTMLResultLength else {
                throw BrowserError.serializationFailed("HTML result exceeds 5,000,000 characters")
            }
            return try codec.encode(html)
        case "text":
            return try codec.encode(try await browserManager.documentText(in: browserID(args, method)))

        case "exists":
            return try codec.encode(try await browserManager.elementExists(
                try string(args, 1, "selector", method), in: browserID(args, method)
            ))
        case "count":
            return try codec.encode(try await browserManager.elementCount(
                try string(args, 1, "selector", method), in: browserID(args, method)
            ))
        case "query":
            return try codec.encodeJSON(try await browserManager.elementProperty(
                try string(args, 2, "property", method),
                selector: try string(args, 1, "selector", method),
                in: browserID(args, method)
            ).bridgeJSONValue)

        case "click", "focus", "blur", "clear", "submit", "scrollIntoView",
             "setValue", "type", "setChecked", "selectValue", "selectIndex":
            let id = try browserID(args, method)
            let selector = try string(args, 1, "selector", method)
            try await browserManager.perform(try elementAction(method, args), selector: selector, in: id)
            return try codec.encode(["completed": true])

        case "waitNavigation":
            let id = try browserID(args, method)
            let input: BrowserNavigationConditionInput = try required(args, 1, name: "condition", method: method)
            let options: BrowserTimeoutOptions? = try optional(args, 2, method: method)
            let result = try await browserManager.wait(
                for: try navigationCondition(input, method: method),
                in: id, timeout: try timeout(options?.timeoutMs, method: method)
            )
            return try codec.encodeJSON(snapshotValue(result))

        case "cookies":
            let id = try browserID(args, method)
            let filter: BrowserCookieFilter? = try optional(args, 1, method: method)
            let cookies = try await browserManager.cookies(in: id).filter { cookie in
                (filter?.domain == nil || cookie.domain == filter?.domain) &&
                (filter?.name == nil || cookie.name == filter?.name) &&
                (filter?.url == nil || filter?.url.flatMap(URL.init(string:)).map {
                    $0.host?.hasSuffix(cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) == true
                } == true)
            }
            return try codec.encode(cookies)
        case "importCookies":
            let cookies: [BrowserCookie] = try required(args, 1, name: "cookies", method: method)
            try await browserManager.importCookies(cookies, into: browserID(args, method))
            return "null"
        case "clearCookies":
            try await browserManager.clearCookies(in: browserID(args, method)); return "null"

        case "websiteData":
            let snapshot = try await browserManager.inspectStorage(in: browserID(args, method))
            return try codec.encodeJSON(.object([
                "state": .string(snapshot.state.rawValue),
                "recordCount": .number(Double(snapshot.recordCount)),
                "dataTypes": .array(snapshot.dataTypes.sorted().map(JSONValue.string))
            ]))
        case "clearWebsiteData":
            let id = try browserID(args, method)
            let scopeName = args.count > 1 ? args[1].stringValue : nil
            let scope: BrowserStorageScope
            switch scopeName {
            case "cache": scope = .cache
            case "localStorage": scope = .localStorage
            case "sessionStorage": scope = .sessionStorage
            case nil, "all": scope = .all
            default: throw BridgeArgumentError(method: method, argument: "scope", expected: "all/cache/localStorage/sessionStorage", received: scopeName ?? "unknown")
            }
            try await browserManager.clearStorage(scope, in: id); return "null"

        case "setUserAgent":
            try browserManager.updateUserAgent(.custom(try string(args, 1, "userAgent", method)), for: browserID(args, method))
            return "null"
        case "resetUserAgent":
            try browserManager.updateUserAgent(.systemDefault, for: browserID(args, method)); return "null"
        case "viewport":
            return try codec.encode(try browserManager.snapshot(for: browserID(args, method)).viewport)

        case "screenshot":
            let id = try browserID(args, method)
            let options: BrowserScreenshotOptions? = try optional(args, 1, method: method)
            let format: BrowserScreenshotResult.Format = options?.format == "jpeg" ? .jpeg : .png
            let quality = options?.quality ?? 0.9
            guard quality.isFinite, (0...1).contains(quality) else {
                throw BridgeArgumentError(method: method, argument: "quality", expected: "number from 0 to 1", received: "out of range")
            }
            let result = try await browserManager.captureScreenshot(
                in: id, format: format, quality: quality,
                fullContent: options?.capture == "fullContent"
            )
            return try codec.encodeJSON(.object([
                "fileId": .string(result.fileURL.lastPathComponent),
                "format": .string(result.format.rawValue),
                "width": .number(Double(result.width)),
                "height": .number(Double(result.height)),
                "timestamp": .string(ISO8601DateFormatter().string(from: result.timestamp)),
                "browserId": .string(result.browserId.description)
            ]))

        case "capabilities":
            return try codec.encode(BrowserBridgeCapabilities())
        default:
            throw BrowserError.unsupportedOperation(method)
        }
    }

    func stop() {
        let ids = ownedBrowsers
        ownedBrowsers.removeAll()
        Task { @MainActor [browserManager] in
            for id in ids { try? await browserManager.destroySession(id) }
        }
    }

    private func decodePayload(_ source: String, method: String) throws -> JSONValue {
        guard let data = source.data(using: .utf8) else {
            throw BridgeArgumentError(method: method, argument: "payload", expected: "UTF-8 JSON", received: "invalid string")
        }
        do { return try JSONDecoder().decode(JSONValue.self, from: data) }
        catch { throw BridgeArgumentError(method: method, argument: "payload", expected: "acyclic JSON", received: "invalid JSON") }
    }

    private func browserID(_ args: [JSONValue], _ method: String) throws -> BrowserID {
        let value = try string(args, 0, "browserId", method)
        guard let uuid = UUID(uuidString: value) else {
            throw BridgeArgumentError(method: method, argument: "browserId", expected: "UUID string", received: "string")
        }
        return BrowserID(rawValue: uuid)
    }

    private func string(_ args: [JSONValue], _ index: Int, _ name: String, _ method: String) throws -> String {
        guard args.indices.contains(index), let value = args[index].stringValue else {
            throw BridgeArgumentError(method: method, argument: name, expected: "string", received: args.indices.contains(index) ? args[index].typeName : "undefined")
        }
        return value
    }

    private func required<T: Decodable>(_ args: [JSONValue], _ index: Int, name: String, method: String) throws -> T {
        guard args.indices.contains(index) else {
            throw BridgeArgumentError(method: method, argument: name, expected: String(describing: T.self), received: "undefined")
        }
        return try codec.decode(T.self, from: args[index], method: method)
    }

    private func optional<T: Decodable>(_ args: [JSONValue], _ index: Int, method: String) throws -> T? {
        guard args.indices.contains(index) else { return nil }
        if case .null = args[index] { return nil }
        return try codec.decode(T.self, from: args[index], method: method)
    }

    private func timeout(_ milliseconds: Double?, method: String) throws -> TimeInterval {
        let value = (milliseconds ?? 30_000) / 1_000
        guard value.isFinite, value >= limits.minimumTimeout, value <= limits.maximumTimeout else {
            throw BridgeArgumentError(method: method, argument: "timeoutMs", expected: "100...120000", received: "out of range")
        }
        return value
    }

    private func makeRequest(_ input: BrowserLoadRequest, method: String) throws -> BrowserRequest {
        guard let url = URL(string: input.url) else { throw BrowserError.invalidURL(input.url) }
        guard let httpMethod = BrowserHTTPMethod(rawValue: input.method?.uppercased() ?? "GET") else {
            throw BridgeArgumentError(method: method, argument: "request.method", expected: "supported HTTP method", received: input.method ?? "unknown")
        }
        guard (input.headers?.count ?? 0) <= limits.maximumHeaders else {
            throw BridgeArgumentError(method: method, argument: "request.headers", expected: "<= 64 headers", received: "oversized")
        }
        let cachePolicy: URLRequest.CachePolicy
        switch input.cachePolicy {
        case nil, "useProtocolCachePolicy": cachePolicy = .useProtocolCachePolicy
        case "reloadIgnoringLocalCacheData": cachePolicy = .reloadIgnoringLocalCacheData
        case "returnCacheDataElseLoad": cachePolicy = .returnCacheDataElseLoad
        case "returnCacheDataDontLoad": cachePolicy = .returnCacheDataDontLoad
        default: throw BridgeArgumentError(method: method, argument: "request.cachePolicy", expected: "supported cache policy", received: input.cachePolicy ?? "unknown")
        }
        return BrowserRequest(
            url: url, method: httpMethod, headers: input.headers ?? [:],
            body: input.body?.data(using: .utf8), cachePolicy: cachePolicy,
            timeout: try timeout(input.timeoutMs, method: method)
        )
    }

    private func elementAction(_ method: String, _ args: [JSONValue]) throws -> BrowserElementAction {
        switch method {
        case "click": return .click
        case "focus": return .focus
        case "blur": return .blur
        case "clear": return .clear
        case "submit": return .submit
        case "scrollIntoView": return .scrollIntoView
        case "setValue": return .setValue(try string(args, 2, "value", method))
        case "type": return .type(try string(args, 2, "text", method))
        case "setChecked":
            guard args.indices.contains(2), case .bool(let value) = args[2] else {
                throw BridgeArgumentError(method: method, argument: "checked", expected: "boolean", received: args.indices.contains(2) ? args[2].typeName : "undefined")
            }
            return .setChecked(value)
        case "selectValue": return .selectValue(try string(args, 2, "value", method))
        case "selectIndex":
            guard args.indices.contains(2), case .number(let value) = args[2], value.rounded() == value else {
                throw BridgeArgumentError(method: method, argument: "index", expected: "integer", received: args.indices.contains(2) ? args[2].typeName : "undefined")
            }
            return .selectIndex(Int(value))
        default: throw BrowserError.unsupportedOperation(method)
        }
    }

    private func navigationCondition(_ input: BrowserNavigationConditionInput, method: String) throws -> NavigationCondition {
        switch input.type {
        case "started": return .started
        case "committed": return .committed
        case "finished": return .finished
        case "failed": return .failed
        case "urlEquals": return .urlEquals(try conditionValue(input, method))
        case "urlContains": return .urlContains(try conditionValue(input, method))
        case "urlPrefix": return .urlPrefix(try conditionValue(input, method))
        case "urlSuffix": return .urlSuffix(try conditionValue(input, method))
        case "urlRegex": return .urlRegex(try conditionValue(input, method))
        case "titleEquals": return .titleEquals(try conditionValue(input, method))
        case "titleContains": return .titleContains(try conditionValue(input, method))
        case "titleRegex": return .titleRegex(try conditionValue(input, method))
        default: throw BridgeArgumentError(method: method, argument: "condition.type", expected: "supported navigation condition", received: input.type)
        }
    }

    private func conditionValue(_ input: BrowserNavigationConditionInput, _ method: String) throws -> String {
        guard let value = input.value else {
            throw BridgeArgumentError(method: method, argument: "condition.value", expected: "string", received: "undefined")
        }
        return value
    }

    private func snapshotValue(_ snapshot: BrowserSnapshot) -> JSONValue {
        .object([
            "browserId": .string(snapshot.browserId.description),
            "state": .string(snapshot.state.rawValue),
            "url": snapshot.navigation.currentURL.map { .string($0.absoluteString) } ?? .null,
            "previousUrl": snapshot.navigation.previousURL.map { .string($0.absoluteString) } ?? .null,
            "title": snapshot.navigation.title.map(JSONValue.string) ?? .null,
            "progress": .number(snapshot.navigation.estimatedProgress),
            "userAgent": snapshot.userAgent.map(JSONValue.string) ?? .null,
            "viewport": .object([
                "width": .number(snapshot.viewport.width),
                "height": .number(snapshot.viewport.height),
                "scale": .number(snapshot.viewport.scale)
            ]),
            "createdAt": .string(ISO8601DateFormatter().string(from: snapshot.createdAt))
        ])
    }
}

private extension BrowserValue {
    var bridgeJSONValue: JSONValue {
        switch self {
        case .null: return .null
        case .bool(let value): return .bool(value)
        case .integer(let value): return .number(Double(value))
        case .number(let value): return .number(value)
        case .string(let value): return .string(value)
        case .array(let values): return .array(values.map(\.bridgeJSONValue))
        case .object(let values): return .object(values.mapValues(\.bridgeJSONValue))
        }
    }
}

private extension BridgeValueCodec {
    func encodeJSON(_ value: JSONValue) throws -> String { try encode(value) }
}
