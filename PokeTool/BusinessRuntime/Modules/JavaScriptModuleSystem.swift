import Foundation
import JavaScriptCore

enum JavaScriptModuleErrorCode: String, Codable {
    case moduleNotFound = "MODULE_NOT_FOUND"
    case invalidModuleID = "INVALID_MODULE_ID"
    case pathOutsideRoot = "MODULE_PATH_OUTSIDE_ROOT"
    case sourceUnavailable = "MODULE_SOURCE_UNAVAILABLE"
    case compileFailed = "MODULE_COMPILE_FAILED"
    case executionFailed = "MODULE_EXECUTION_FAILED"
    case exportFailed = "MODULE_EXPORT_FAILED"
    case circularDependency = "CIRCULAR_DEPENDENCY_ERROR"
    case cacheError = "MODULE_CACHE_ERROR"
    case resourceLimitExceeded = "RESOURCE_LIMIT_EXCEEDED"
    case runtimeStopped = "MODULE_RUNTIME_STOPPED"
    case unsupportedFeature = "UNSUPPORTED_MODULE_FEATURE"
    case internalError = "INTERNAL_MODULE_ERROR"
}

struct JavaScriptModuleError: LocalizedError {
    let code: JavaScriptModuleErrorCode
    let message: String
    let requestedID: String?
    let canonicalID: String?
    let parentModuleID: String?
    let phase: String

    var errorDescription: String? { message }

    var payload: [String: Any] {
        [
            "name": "RuntimeModuleError",
            "code": code.rawValue,
            "message": message,
            "requestedId": requestedID as Any? ?? NSNull(),
            "canonicalId": canonicalID as Any? ?? NSNull(),
            "parentModuleId": parentModuleID as Any? ?? NSNull(),
            "phase": phase,
            "retryable": false
        ]
    }
}

struct JavaScriptModuleLimits: Equatable {
    let maximumModules = 512
    let maximumSourceBytes = 1_048_576
    let maximumTotalSourceBytes = 16_777_216
    let maximumDependencyDepth = 128
    let maximumPathLength = 512
    let maximumActiveTimers = 128
    let minimumTimerDelayMilliseconds = 4
    let maximumTimerDelayMilliseconds = 120_000
    let maximumConsolePayloadBytes = 16_384
}

struct JavaScriptModuleSource: Equatable {
    let canonicalID: String
    let filename: String
    let directory: String
    let source: String
    let origin: String
    let byteCount: Int
}

protocol JavaScriptModuleResolving {
    func resolve(_ request: String, from parentID: String?) throws -> String
}

struct JavaScriptModuleResolver: JavaScriptModuleResolving {
    let limits: JavaScriptModuleLimits

    func resolve(_ request: String, from parentID: String?) throws -> String {
        guard !request.isEmpty, request.count <= limits.maximumPathLength,
              !request.contains("\0") else {
            throw error(.invalidModuleID, request, parentID, "Module identifier is invalid.")
        }
        let lower = request.lowercased()
        guard !lower.contains("://"), !lower.hasPrefix("file:"),
              !request.contains("\\"), !request.contains(":") else {
            throw error(.invalidModuleID, request, parentID, "Only logical JavaScript module paths are supported.")
        }

        let raw: String
        if request.hasPrefix("/") {
            raw = request
        } else {
            let parentDirectory = parentID.map { ($0 as NSString).deletingLastPathComponent } ?? "/"
            raw = parentDirectory + "/" + request
        }

        var components: [String] = []
        for component in raw.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".": continue
            case "..":
                guard !components.isEmpty else {
                    throw error(.pathOutsideRoot, request, parentID, "Module path escapes the JavaScript root.")
                }
                components.removeLast()
            default:
                components.append(String(component))
            }
        }
        guard !components.isEmpty else {
            throw error(.invalidModuleID, request, parentID, "Module identifier resolves to the root.")
        }
        var canonical = "/" + components.joined(separator: "/")
        if (canonical as NSString).pathExtension.isEmpty { canonical += ".js" }
        guard canonical.hasSuffix(".js") else {
            throw error(.invalidModuleID, request, parentID, "Only .js modules are supported.")
        }
        return canonical
    }

    private func error(
        _ code: JavaScriptModuleErrorCode, _ request: String, _ parent: String?, _ message: String
    ) -> JavaScriptModuleError {
        JavaScriptModuleError(
            code: code, message: message, requestedID: request,
            canonicalID: nil, parentModuleID: parent, phase: "resolve"
        )
    }
}

protocol JavaScriptModuleSourceProviding {
    func source(for canonicalID: String) throws -> JavaScriptModuleSource
}

struct BundleJavaScriptModuleSourceProvider: JavaScriptModuleSourceProviding {
    let bundle: Bundle
    let limits: JavaScriptModuleLimits

    func source(for canonicalID: String) throws -> JavaScriptModuleSource {
        let logical = String(canonicalID.dropFirst())
        let relative = "JavaScript/" + logical
        let candidates = [
            bundle.resourceURL?.appendingPathComponent(relative),
            bundle.resourceURL?.appendingPathComponent(logical),
            bundle.url(
                forResource: (logical as NSString).deletingPathExtension,
                withExtension: "js",
                subdirectory: "JavaScript"
            ),
            bundle.url(
                forResource: (logical as NSString).lastPathComponent.replacingOccurrences(of: ".js", with: ""),
                withExtension: "js"
            )
        ].compactMap { $0 }
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = try? Data(contentsOf: url) else {
            throw JavaScriptModuleError(
                code: .moduleNotFound, message: "Module was not found.",
                requestedID: canonicalID, canonicalID: canonicalID,
                parentModuleID: nil, phase: "load"
            )
        }
        guard data.count <= limits.maximumSourceBytes else {
            throw JavaScriptModuleError(
                code: .resourceLimitExceeded, message: "Module source exceeds the configured size limit.",
                requestedID: canonicalID, canonicalID: canonicalID,
                parentModuleID: nil, phase: "load"
            )
        }
        guard let source = String(data: data, encoding: .utf8) else {
            throw JavaScriptModuleError(
                code: .sourceUnavailable, message: "Module source is not valid UTF-8.",
                requestedID: canonicalID, canonicalID: canonicalID,
                parentModuleID: nil, phase: "load"
            )
        }
        return JavaScriptModuleSource(
            canonicalID: canonicalID,
            filename: canonicalID,
            directory: (canonicalID as NSString).deletingLastPathComponent,
            source: source,
            origin: "applicationBundle",
            byteCount: data.count
        )
    }
}

struct InMemoryJavaScriptModuleSourceProvider: JavaScriptModuleSourceProviding {
    let sources: [String: String]
    let limits: JavaScriptModuleLimits

    func source(for canonicalID: String) throws -> JavaScriptModuleSource {
        guard let source = sources[canonicalID] else {
            throw JavaScriptModuleError(
                code: .moduleNotFound, message: "Module was not found.",
                requestedID: canonicalID, canonicalID: canonicalID,
                parentModuleID: nil, phase: "load"
            )
        }
        let bytes = source.lengthOfBytes(using: .utf8)
        guard bytes <= limits.maximumSourceBytes else {
            throw JavaScriptModuleError(
                code: .resourceLimitExceeded, message: "Module source exceeds the configured size limit.",
                requestedID: canonicalID, canonicalID: canonicalID,
                parentModuleID: nil, phase: "load"
            )
        }
        return JavaScriptModuleSource(
            canonicalID: canonicalID, filename: canonicalID,
            directory: (canonicalID as NSString).deletingLastPathComponent,
            source: source, origin: "memory", byteCount: bytes
        )
    }
}

@objc protocol RuntimeBridgeNamespaceExport: JSExport {
    var runtimeID: String { get }
    func resolveModule(_ request: String, _ parentID: String?) -> String
    func loadModuleSource(_ canonicalID: String) -> String
    func scheduleTimer(_ callback: JSValue, _ delayMilliseconds: Double, _ repeats: Bool) -> Int
    func clearTimer(_ timerID: Int)
    func activeTimerCount() -> Int
    func monotonicMilliseconds() -> Double
}

@MainActor
@objcMembers
final class RuntimeBridgeNamespace: NSObject, RuntimeBridgeNamespaceExport {
    let runtimeID: String
    let limits: JavaScriptModuleLimits
    private let resolver: JavaScriptModuleResolving
    private let sourceProvider: JavaScriptModuleSourceProviding
    private let logger: Logging
    private var timers: [Int: Task<Void, Never>] = [:]
    private var callbacks: [Int: JSValue] = [:]
    private var nextTimerID = 1
    private var stopped = false

    init(
        resolver: JavaScriptModuleResolving,
        sourceProvider: JavaScriptModuleSourceProviding,
        limits: JavaScriptModuleLimits,
        logger: Logging,
        runtimeID: String = UUID().uuidString
    ) {
        self.runtimeID = runtimeID
        self.resolver = resolver
        self.sourceProvider = sourceProvider
        self.limits = limits
        self.logger = logger
    }

    func resolveModule(_ request: String, _ parentID: String?) -> String {
        resultJSON {
            ["canonicalId": try resolver.resolve(request, from: parentID)]
        }
    }

    func loadModuleSource(_ canonicalID: String) -> String {
        resultJSON {
            let item = try sourceProvider.source(for: canonicalID)
            return [
                "canonicalId": item.canonicalID, "filename": item.filename,
                "dirname": item.directory, "source": item.source,
                "origin": item.origin, "byteCount": item.byteCount
            ]
        }
    }

    func scheduleTimer(_ callback: JSValue, _ delayMilliseconds: Double, _ repeats: Bool) -> Int {
        guard !stopped, !callback.isUndefined, callbacks.count < limits.maximumActiveTimers,
              delayMilliseconds.isFinite else { return 0 }
        let bounded = min(
            max(Int(delayMilliseconds), limits.minimumTimerDelayMilliseconds),
            limits.maximumTimerDelayMilliseconds
        )
        let id = nextTimerID
        nextTimerID += 1
        callbacks[id] = callback
        timers[id] = Task { @MainActor [weak self] in
            repeat {
                do { try await Task.sleep(for: .milliseconds(bounded)) }
                catch { break }
                guard let self, !Task.isCancelled, let callback = self.callbacks[id] else { break }
                callback.call(withArguments: [])
                if let exception = callback.context?.exception {
                    self.logger.log(
                        .error, category: .runtime, message: "Runtime timer callback failed",
                        metadata: ["runtimeId": self.runtimeID, "error": String(exception.toString().prefix(500))]
                    )
                    callback.context?.exception = nil
                }
            } while repeats
            self?.releaseTimer(id)
        }
        return id
    }

    func clearTimer(_ timerID: Int) {
        timers[timerID]?.cancel()
        releaseTimer(timerID)
    }

    func activeTimerCount() -> Int { timers.count }

    func monotonicMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }

    func prepareForStart() {
        stopped = false
        nextTimerID = 1
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        for id in Array(timers.keys) { clearTimer(id) }
    }

    private func releaseTimer(_ id: Int) {
        timers[id] = nil
        callbacks[id] = nil
    }

    private func resultJSON(_ body: () throws -> [String: Any]) -> String {
        do {
            return json(["ok": true, "value": try body()])
        } catch let error as JavaScriptModuleError {
            return json(["ok": false, "error": error.payload])
        } catch {
            let moduleError = JavaScriptModuleError(
                code: .internalError, message: "Internal module system failure.",
                requestedID: nil, canonicalID: nil, parentModuleID: nil, phase: "load"
            )
            return json(["ok": false, "error": moduleError.payload])
        }
    }

    private func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"ok":false,"error":{"name":"RuntimeModuleError","code":"INTERNAL_MODULE_ERROR","message":"Serialization failed.","phase":"load","retryable":false}}"#
        }
        return string
    }
}
