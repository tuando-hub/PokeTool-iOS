import Foundation
import JavaScriptCore
import Security
import UserNotifications

struct InfrastructureResourceLimits {
    let maximumPendingOperations = 64
    let maximumKeyLength = 256
    let maximumValueBytes = 256 * 1_024
    let maximumFileBytes = 8 * 1_024 * 1_024
    let maximumURLLength = 4_096
    let maximumHeaders = 64
    let maximumHeaderBytes = 32 * 1_024
    let maximumRequestBytes = 4 * 1_024 * 1_024
    let maximumResponseBytes = 16 * 1_024 * 1_024
    let minimumTimeoutMilliseconds = 100
    let maximumTimeoutMilliseconds = 120_000
    let maximumKeychainBytes = 64 * 1_024
    let maximumRandomBytes = 65_536
    let maximumSleepMilliseconds = 120_000
    let maximumEventPayloadBytes = 64 * 1_024
    let maximumNotificationText = 4_096
}

struct InfrastructureBridgeError: Error {
    let code: String
    let message: String
    let namespace: String
    let operation: String
    let retryable: Bool
    let details: [String: String]

    func object(operationID: String, runtimeID: String) -> [String: Any] {
        [
            "name": "\(namespace)Error", "code": code, "message": message,
            "namespace": namespace, "operation": operation,
            "operationId": operationID, "runtimeId": runtimeID,
            "retryable": retryable, "details": details
        ]
    }
}

@MainActor
protocol InfrastructureBridgeServicing: AnyObject {
    var namespace: String { get }
    var version: String { get }
    var capabilities: [String: Any] { get }
    func perform(method: String, arguments: [Any]) async throws -> Any
    func stop()
    func prepareForStart()
}

@objc protocol InfrastructureBridgeNamespaceExport: JSExport {
    var version: String { get }
    func invoke(_ method: String, _ payloadJSON: String) -> JSValue
    func cancel(_ operationID: String) -> Bool
    func capabilities() -> JSValue
}

@MainActor
@objcMembers
final class InfrastructureBridgeNamespace: NSObject, InfrastructureBridgeNamespaceExport {
    private struct Entry {
        let task: Task<Void, Never>
        let resolve: JSValue
        let reject: JSValue
        let method: String
    }

    var version: String { service.version }
    private let service: InfrastructureBridgeServicing
    private let runtimeID: String
    private let limits: InfrastructureResourceLimits
    private var entries: [String: Entry] = [:]
    private var stopped = false

    init(
        service: InfrastructureBridgeServicing,
        runtimeID: String,
        limits: InfrastructureResourceLimits
    ) {
        self.service = service
        self.runtimeID = runtimeID
        self.limits = limits
    }

    func invoke(_ method: String, _ payloadJSON: String) -> JSValue {
        guard let context = JSContext.current() else { return JSValue(undefinedIn: nil) }
        let operationID = UUID().uuidString
        guard !stopped, entries.count < limits.maximumPendingOperations else {
            return rejectedPromise(
                in: context, operationID: operationID, method: method,
                code: stopped ? "\(service.namespace.uppercased())_RUNTIME_STOPPED" : "RESOURCE_LIMIT_EXCEEDED",
                message: stopped ? "Runtime has stopped." : "Pending operation limit reached."
            )
        }
        guard let arguments = Self.arguments(payloadJSON) else {
            return rejectedPromise(
                in: context, operationID: operationID, method: method,
                code: "\(service.namespace.uppercased())_INVALID_REQUEST",
                message: "Arguments must be finite JSON-compatible values."
            )
        }
        guard let holder = context.evaluateScript(
            "(function(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject};})()"
        ), let promise = holder.forProperty("promise"),
           let resolve = holder.forProperty("resolve"), let reject = holder.forProperty("reject") else {
            return JSValue(undefinedIn: context)
        }
        promise.setValue(operationID, forProperty: "operationId")
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let value = try await self.service.perform(method: method, arguments: arguments)
                self.settle(operationID, value: value, error: nil)
            } catch is CancellationError {
                self.settle(
                    operationID, value: nil,
                    error: InfrastructureBridgeError(
                        code: "\(self.service.namespace.uppercased())_CANCELLED",
                        message: "Operation was cancelled.", namespace: self.service.namespace,
                        operation: method, retryable: false, details: [:]
                    )
                )
            } catch let error as InfrastructureBridgeError {
                self.settle(operationID, value: nil, error: error)
            } catch {
                self.settle(
                    operationID, value: nil,
                    error: InfrastructureBridgeError(
                        code: "\(self.service.namespace.uppercased())_INTERNAL_ERROR",
                        message: "Infrastructure operation failed.", namespace: self.service.namespace,
                        operation: method, retryable: false, details: [:]
                    )
                )
            }
        }
        entries[operationID] = Entry(task: task, resolve: resolve, reject: reject, method: method)
        return promise
    }

    func cancel(_ operationID: String) -> Bool {
        guard let entry = entries.removeValue(forKey: operationID) else { return false }
        entry.task.cancel()
        let error = InfrastructureBridgeError(
            code: "\(service.namespace.uppercased())_CANCELLED",
            message: "Operation was cancelled.", namespace: service.namespace,
            operation: entry.method, retryable: false, details: [:]
        )
        entry.reject.call(withArguments: [error.object(operationID: operationID, runtimeID: runtimeID)])
        return true
    }

    func capabilities() -> JSValue {
        JSValue(object: service.capabilities, in: JSContext.current())
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        for id in Array(entries.keys) { _ = cancel(id) }
        service.stop()
    }

    func prepareForStart() {
        stopped = false
        service.prepareForStart()
    }

    private func settle(_ id: String, value: Any?, error: InfrastructureBridgeError?) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        if let error {
            entry.reject.call(withArguments: [error.object(operationID: id, runtimeID: runtimeID)])
        } else {
            entry.resolve.call(withArguments: [value ?? NSNull()])
        }
    }

    private func rejectedPromise(
        in context: JSContext, operationID: String, method: String, code: String, message: String
    ) -> JSValue {
        let error = InfrastructureBridgeError(
            code: code, message: message, namespace: service.namespace,
            operation: method, retryable: false, details: [:]
        )
        guard let reject = context.evaluateScript("Promise.reject") else {
            return JSValue(undefinedIn: context)
        }
        return reject.call(withArguments: [
            error.object(operationID: operationID, runtimeID: runtimeID)
        ])
    }

    private static func arguments(_ json: String) -> [Any]? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arguments = object["args"] as? [Any] else { return nil }
        return arguments
    }
}

@MainActor
class BaseInfrastructureService: InfrastructureBridgeServicing {
    let namespace: String
    let version = "1.0.0"
    var capabilities: [String: Any] { [:] }
    var stopped = false

    init(namespace: String) { self.namespace = namespace }
    func perform(method: String, arguments: [Any]) async throws -> Any {
        throw failure("UNSUPPORTED_OPERATION", "Operation is not supported.", method)
    }
    func stop() { stopped = true }
    func prepareForStart() { stopped = false }
    func checkRunning(_ method: String) throws {
        if stopped { throw failure("\(namespace.uppercased())_RUNTIME_STOPPED", "Runtime has stopped.", method) }
    }
    func failure(_ code: String, _ message: String, _ method: String) -> InfrastructureBridgeError {
        InfrastructureBridgeError(
            code: code, message: message, namespace: namespace,
            operation: method, retryable: false, details: [:]
        )
    }
}

final class StorageBridgeService: BaseInfrastructureService {
    private let store: FileStore
    private let limits: InfrastructureResourceLimits
    override var capabilities: [String: Any] {
        ["keyValue": true, "text": true, "json": true, "base64": true, "temporary": true]
    }

    init(store: FileStore, limits: InfrastructureResourceLimits) {
        self.store = store; self.limits = limits; super.init(namespace: "Storage")
    }

    override func perform(method: String, arguments: [Any]) async throws -> Any {
        try checkRunning(method)
        do {
            switch method {
            case "get": return try await store.get(string(arguments, 0, method))?.foundationValue ?? NSNull()
            case "set":
                let key = try string(arguments, 0, method)
                let value = try JSONValue(any: argument(arguments, 1, method))
                try await store.set(key, value: value); return true
            case "remove": try await store.remove(string(arguments, 0, method)); return true
            case "contains": return try await store.contains(string(arguments, 0, method))
            case "keys": return await store.keys(prefix: optionalString(arguments, 0))
            case "clear": return try await store.clear(prefix: optionalString(arguments, 0))
            case "readText":
                let data = try await store.read(string(arguments, 0, method))
                guard let text = String(data: data, encoding: .utf8) else {
                    throw failure("STORAGE_SERIALIZATION_FAILED", "File is not UTF-8 text.", method)
                }
                return text
            case "writeText":
                let path = try string(arguments, 0, method)
                let text = try string(arguments, 1, method)
                try await store.write(path, data: Data(text.utf8), overwrite: overwrite(arguments, 2)); return true
            case "readJSON":
                let data = try await store.read(string(arguments, 0, method))
                return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            case "writeJSON":
                let data = try JSONSerialization.data(
                    withJSONObject: argument(arguments, 1, method), options: [.fragmentsAllowed]
                )
                try await store.write(string(arguments, 0, method), data: data, overwrite: overwrite(arguments, 2))
                return true
            case "readBinary": return try await store.read(string(arguments, 0, method)).base64EncodedString()
            case "writeBinary":
                guard let data = Data(base64Encoded: try string(arguments, 1, method)) else {
                    throw failure("STORAGE_SERIALIZATION_FAILED", "Binary value must be valid base64.", method)
                }
                try await store.write(string(arguments, 0, method), data: data, overwrite: overwrite(arguments, 2))
                return true
            case "exists": return try await store.exists(string(arguments, 0, method))
            case "info": return try foundation(try await store.info(string(arguments, 0, method)))
            case "list": return try (try await store.list(optionalString(arguments, 0) ?? "/data")).map(foundation)
            case "createDirectory": try await store.createDirectory(string(arguments, 0, method)); return true
            case "removePath": try await store.removePath(string(arguments, 0, method)); return true
            case "move":
                try await store.move(
                    string(arguments, 0, method), to: string(arguments, 1, method),
                    overwrite: overwrite(arguments, 2)
                ); return true
            case "copy":
                try await store.copy(
                    string(arguments, 0, method), to: string(arguments, 1, method),
                    overwrite: overwrite(arguments, 2)
                ); return true
            case "temporaryFile":
                return try await store.temporaryFile(extension: optionalString(arguments, 0))
            case "cleanupTemporary":
                let age = (arguments.first as? NSNumber)?.doubleValue ?? 86_400_000
                return try await store.cleanupTemporary(olderThan: Date(timeIntervalSinceNow: -age / 1_000))
            default: return try await super.perform(method: method, arguments: arguments)
            }
        } catch let error as InfrastructureBridgeError { throw error }
        catch let error as ManagedStorageError {
            let code: String
            switch error {
            case .invalidKey: code = "STORAGE_INVALID_KEY"
            case .invalidPath: code = "STORAGE_INVALID_PATH"
            case .outsideRoot: code = "STORAGE_PATH_OUTSIDE_ROOT"
            case .notFound: code = "STORAGE_NOT_FOUND"
            case .alreadyExists: code = "STORAGE_ALREADY_EXISTS"
            case .tooLarge: code = "STORAGE_FILE_TOO_LARGE"
            case .serialization: code = "STORAGE_SERIALIZATION_FAILED"
            case .io: code = "STORAGE_IO_FAILED"
            }
            throw failure(code, "Storage operation failed.", method)
        } catch {
            throw failure("STORAGE_IO_FAILED", "Storage operation failed.", method)
        }
    }

    private func overwrite(_ args: [Any], _ index: Int) -> Bool {
        (args.indices.contains(index) ? args[index] as? [String: Any] : nil)?["overwrite"] as? Bool ?? false
    }
}

final class KeychainBridgeService: BaseInfrastructureService {
    private let store: KeychainStoring
    private let limits: InfrastructureResourceLimits
    override var capabilities: [String: Any] { ["string": true, "base64": false, "accessGroup": false] }
    init(store: KeychainStoring, limits: InfrastructureResourceLimits) {
        self.store = store; self.limits = limits; super.init(namespace: "Keychain")
    }
    override func perform(method: String, arguments: [Any]) async throws -> Any {
        try checkRunning(method)
        let key = try string(arguments, 0, method)
        guard key.count <= limits.maximumKeyLength else {
            throw failure("KEYCHAIN_INVALID_KEY", "Key is invalid.", method)
        }
        do {
            switch method {
            case "get":
                guard let data = try store.data(account: key) else { return NSNull() }
                guard let value = String(data: data, encoding: .utf8) else {
                    throw failure("KEYCHAIN_ENCODING_FAILED", "Secret is not UTF-8.", method)
                }
                return value
            case "set":
                let value = try string(arguments, 1, method)
                guard value.utf8.count <= limits.maximumKeychainBytes else {
                    throw failure("KEYCHAIN_ENCODING_FAILED", "Secret exceeds size limit.", method)
                }
                try store.set(Data(value.utf8), account: key); return true
            case "remove": try store.remove(account: key); return true
            case "contains": return try store.data(account: key) != nil
            default: return try await super.perform(method: method, arguments: arguments)
            }
        } catch let error as InfrastructureBridgeError { throw error }
        catch { throw failure("KEYCHAIN_ACCESS_FAILED", "Keychain operation failed.", method) }
    }
}

final class NetworkBridgeService: BaseInfrastructureService {
    private let client: NetworkTransporting
    private let limits: InfrastructureResourceLimits
    override var capabilities: [String: Any] {
        ["http": true, "https": true, "responseTypes": ["text", "json", "base64", "metadataOnly"],
         "redirectControl": "systemDefault", "cookieSync": false]
    }
    init(client: NetworkTransporting, limits: InfrastructureResourceLimits) {
        self.client = client; self.limits = limits; super.init(namespace: "Network")
    }
    override func perform(method: String, arguments: [Any]) async throws -> Any {
        try checkRunning(method)
        guard method == "request", let model = arguments.first as? [String: Any] else {
            return try await super.perform(method: method, arguments: arguments)
        }
        guard let rawURL = model["url"] as? String, rawURL.count <= limits.maximumURLLength,
              let url = URL(string: rawURL), let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme) else {
            throw failure("NETWORK_INVALID_URL", "URL or scheme is invalid.", method)
        }
        let verb = (model["method"] as? String ?? "GET").uppercased()
        guard ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"].contains(verb) else {
            throw failure("NETWORK_INVALID_REQUEST", "HTTP method is not allowed.", method)
        }
        var request = URLRequest(url: url)
        request.httpMethod = verb
        let timeout = (model["timeoutMs"] as? NSNumber)?.doubleValue ?? 30_000
        guard timeout >= Double(limits.minimumTimeoutMilliseconds),
              timeout <= Double(limits.maximumTimeoutMilliseconds) else {
            throw failure("NETWORK_INVALID_REQUEST", "Timeout is outside allowed range.", method)
        }
        request.timeoutInterval = timeout / 1_000
        let headers = model["headers"] as? [String: String] ?? [:]
        guard headers.count <= limits.maximumHeaders,
              headers.reduce(0, { $0 + $1.key.utf8.count + $1.value.utf8.count }) <= limits.maximumHeaderBytes,
              headers.allSatisfy({ !$0.key.contains("\n") && !$0.value.contains("\n") }) else {
            throw failure("NETWORK_INVALID_REQUEST", "Headers are invalid.", method)
        }
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let body = model["body"] as? String {
            let encoding = model["bodyEncoding"] as? String ?? "utf8"
            if encoding == "base64" { request.httpBody = Data(base64Encoded: body) }
            else { request.httpBody = Data(body.utf8) }
            guard (request.httpBody?.count ?? 0) <= limits.maximumRequestBytes else {
                throw failure("NETWORK_INVALID_REQUEST", "Request body exceeds size limit.", method)
            }
        }
        do {
            let start = ProcessInfo.processInfo.systemUptime
            let (data, response) = try await client.data(for: request)
            guard data.count <= limits.maximumResponseBytes else {
                throw failure("NETWORK_RESPONSE_TOO_LARGE", "Response exceeds size limit.", method)
            }
            let responseType = model["responseType"] as? String ?? "text"
            let body: Any
            switch responseType {
            case "metadataOnly": body = NSNull()
            case "base64": body = data.base64EncodedString()
            case "json":
                do { body = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) }
                catch { throw failure("NETWORK_DECODING_FAILED", "Response is not valid JSON.", method) }
            default:
                guard let text = String(data: data, encoding: .utf8) else {
                    throw failure("NETWORK_DECODING_FAILED", "Response is not UTF-8.", method)
                }
                body = text
            }
            if model["rejectOnHTTPError"] as? Bool == true, response.statusCode >= 400 {
                throw failure("NETWORK_HTTP_ERROR", "HTTP request returned an error status.", method)
            }
            return [
                "url": response.url?.absoluteString ?? rawURL,
                "statusCode": response.statusCode,
                "headers": response.allHeaderFields.reduce(into: [String: String]()) {
                    $0[String(describing: $1.key)] = String(describing: $1.value)
                },
                "body": body,
                "bodyEncoding": responseType,
                "mimeType": response.mimeType ?? NSNull(),
                "expectedContentLength": response.expectedContentLength,
                "durationMs": (ProcessInfo.processInfo.systemUptime - start) * 1_000,
                "redirected": response.url?.absoluteString != rawURL,
                "redirectCount": 0
            ]
        } catch let error as InfrastructureBridgeError { throw error }
        catch let error as URLError {
            let code: String
            switch error.code {
            case .timedOut: code = "NETWORK_TIMEOUT"
            case .cancelled: code = "NETWORK_CANCELLED"
            case .notConnectedToInternet: code = "NETWORK_OFFLINE"
            case .cannotFindHost, .dnsLookupFailed: code = "NETWORK_DNS_FAILED"
            case .secureConnectionFailed, .serverCertificateUntrusted: code = "NETWORK_TLS_FAILED"
            default: code = "NETWORK_CONNECTION_FAILED"
            }
            throw failure(code, "Network request failed.", method)
        }
    }
}

final class SystemInfrastructureBridgeService: BaseInfrastructureService {
    private let limits: InfrastructureResourceLimits
    override var capabilities: [String: Any] {
        ["sleep": true, "uuid": true, "randomBytes": true, "openURL": false, "memoryInfo": true]
    }
    init(limits: InfrastructureResourceLimits) {
        self.limits = limits; super.init(namespace: "System")
    }
    override func perform(method: String, arguments: [Any]) async throws -> Any {
        try checkRunning(method)
        switch method {
        case "appInfo":
            return [
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
                "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
            ]
        case "runtimeInfo": return ["engine": "JavaScriptCore", "phase": 6]
        case "now": return Date().timeIntervalSince1970 * 1_000
        case "monotonicNow": return ProcessInfo.processInfo.systemUptime * 1_000
        case "sleep":
            let value = (try number(arguments, 0, method)).intValue
            guard value >= 0, value <= limits.maximumSleepMilliseconds else {
                throw failure("SYSTEM_INVALID_ARGUMENT", "Sleep duration is invalid.", method)
            }
            try await Task.sleep(for: .milliseconds(value)); return true
        case "generateUUID": return UUID().uuidString
        case "randomBytes":
            let count = (try number(arguments, 0, method)).intValue
            guard count >= 0, count <= limits.maximumRandomBytes else {
                throw failure("SYSTEM_INVALID_ARGUMENT", "Random byte length is invalid.", method)
            }
            var bytes = [UInt8](repeating: 0, count: count)
            guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
                throw failure("SYSTEM_RANDOM_FAILED", "Random generation failed.", method)
            }
            return Data(bytes).base64EncodedString()
        case "memoryInfo":
            return ["physicalMemory": ProcessInfo.processInfo.physicalMemory]
        case "environment":
            return ["platform": "iOS", "runtime": "JavaScriptCore", "phase": 6]
        default: return try await super.perform(method: method, arguments: arguments)
        }
    }
}

@MainActor
final class DeviceBridgeService: BaseInfrastructureService {
    private let provider: DeviceInformationProviding
    override var capabilities: [String: Any] {
        ["safeInfo": true, "installationId": false, "hardwareIdentifiers": false]
    }
    init(provider: DeviceInformationProviding) {
        self.provider = provider; super.init(namespace: "Device")
    }
    override func perform(method: String, arguments: [Any]) async throws -> Any {
        try checkRunning(method)
        switch method {
        case "info": return try foundation(provider.info())
        case "isLowPowerMode": return provider.info().lowPowerMode
        case "memoryInfo": return ["physicalMemory": ProcessInfo.processInfo.physicalMemory]
        default: return try await super.perform(method: method, arguments: arguments)
        }
    }
}

final class NotificationBridgeService: BaseInfrastructureService {
    private let notifications: NotificationService
    private let limits: InfrastructureResourceLimits
    override var capabilities: [String: Any] {
        ["authorization": true, "timeInterval": true, "calendar": false, "delivered": true]
    }
    init(notifications: NotificationService, limits: InfrastructureResourceLimits) {
        self.notifications = notifications; self.limits = limits; super.init(namespace: "Notification")
    }
    override func perform(method: String, arguments: [Any]) async throws -> Any {
        try checkRunning(method)
        switch method {
        case "authorizationStatus":
            return status(await notifications.authorizationStatus())
        case "requestAuthorization": return try await notifications.requestAuthorization()
        case "schedule":
            guard let request = arguments.first as? [String: Any],
                  let title = request["title"] as? String,
                  let body = request["body"] as? String,
                  title.count + body.count <= limits.maximumNotificationText else {
                throw failure("NOTIFICATION_INVALID_REQUEST", "Notification request is invalid.", method)
            }
            let id = request["identifier"] as? String ?? UUID().uuidString
            let trigger = request["trigger"] as? [String: Any]
            let delay = (trigger?["seconds"] as? NSNumber)?.doubleValue
            try await notifications.notify(
                title: title, subtitle: request["subtitle"] as? String ?? "",
                body: body, identifier: id, delay: delay,
                userInfo: request["userInfo"] as? [String: String] ?? [:]
            )
            return ["identifier": id]
        case "cancel": notifications.cancel(try string(arguments, 0, method)); return true
        case "cancelAll": notifications.cancelAll(); return true
        case "pending": return await notifications.pendingIdentifiers()
        case "delivered": return await notifications.deliveredIdentifiers()
        case "removeDelivered": notifications.removeDelivered(try string(arguments, 0, method)); return true
        case "removeAllDelivered": notifications.removeAllDelivered(); return true
        default: return try await super.perform(method: method, arguments: arguments)
        }
    }
    private func status(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .authorized: "authorized"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown"
        }
    }
}

final class EventsBridgeService: BaseInfrastructureService {
    private let eventBus: EventBus
    override var capabilities: [String: Any] {
        ["emit": true, "allowedPrefixes": ["js.", "runtime.", "plugin."],
         "nativeSubscriptions": false, "compatibilitySubscriptions": "runtimeLocal"]
    }
    init(eventBus: EventBus) { self.eventBus = eventBus; super.init(namespace: "Events") }
    override func perform(method: String, arguments: [Any]) async throws -> Any {
        try checkRunning(method)
        guard method == "emit" else { return try await super.perform(method: method, arguments: arguments) }
        let name = try string(arguments, 0, method)
        guard ["js.", "runtime.", "plugin."].contains(where: name.hasPrefix) else {
            throw failure("EVENT_FORBIDDEN_NAME", "JavaScript cannot emit reserved native events.", method)
        }
        let payload = arguments.indices.contains(1) ? arguments[1] : NSNull()
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.fragmentsAllowed])
        guard data.count <= 64 * 1_024 else {
            throw failure("EVENT_PAYLOAD_TOO_LARGE", "Event payload exceeds size limit.", method)
        }
        eventBus.publish(
            PlatformEvent(
                name: name, source: .runtime,
                attributes: ["payload": String(data: data, encoding: .utf8) ?? "null"]
            )
        )
        return [
            "id": UUID().uuidString, "name": name, "source": "runtime",
            "timestamp": Date().timeIntervalSince1970 * 1_000, "attributes": payload
        ]
    }
}

private func argument(_ arguments: [Any], _ index: Int, _ method: String) throws -> Any {
    guard arguments.indices.contains(index) else {
        throw InfrastructureBridgeError(
            code: "INVALID_ARGUMENT", message: "Required argument is missing.",
            namespace: "Infrastructure", operation: method, retryable: false, details: [:]
        )
    }
    return arguments[index]
}

private func string(_ arguments: [Any], _ index: Int, _ method: String) throws -> String {
    guard let value = try argument(arguments, index, method) as? String else {
        throw InfrastructureBridgeError(
            code: "INVALID_ARGUMENT", message: "Argument must be a string.",
            namespace: "Infrastructure", operation: method, retryable: false, details: [:]
        )
    }
    return value
}

private func optionalString(_ arguments: [Any], _ index: Int) -> String? {
    guard arguments.indices.contains(index), !(arguments[index] is NSNull) else { return nil }
    return arguments[index] as? String
}

private func number(_ arguments: [Any], _ index: Int, _ method: String) throws -> NSNumber {
    guard let value = try argument(arguments, index, method) as? NSNumber else {
        throw InfrastructureBridgeError(
            code: "INVALID_ARGUMENT", message: "Argument must be a number.",
            namespace: "Infrastructure", operation: method, retryable: false, details: [:]
        )
    }
    return value
}

private func foundation<T: Encodable>(_ value: T) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder.infrastructure.encode(value))
}

private extension JSONEncoder {
    static var infrastructure: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONValue {
    init(any value: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }
    var foundationValue: Any {
        switch self {
        case .string(let value): value
        case .number(let value): value
        case .bool(let value): value
        case .object(let value): value.mapValues(\.foundationValue)
        case .array(let value): value.map(\.foundationValue)
        case .null: NSNull()
        }
    }
}
