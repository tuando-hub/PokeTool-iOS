import Foundation
import JavaScriptCore

@objc protocol BrowserBridgeNamespaceExport: JSExport {
    var version: String { get }
    func invoke(_ method: String, _ payloadJSON: String) -> JSValue
    func cancel(_ operationId: String) -> Bool
    func capabilities() -> JSValue
}
@objc protocol StorageBridgeNamespaceExport: JSExport {}
@objc protocol NetworkBridgeNamespaceExport: JSExport {}
@objc protocol NotificationBridgeNamespaceExport: JSExport {}
@objc protocol DeviceBridgeNamespaceExport: JSExport {}
@objc protocol EventsBridgeNamespaceExport: JSExport {}

@objc protocol LoggerBridgeNamespaceExport: JSExport {
    func log(_ level: String, _ message: String)
    func debug(_ message: String, _ metadata: JSValue?)
    func info(_ message: String, _ metadata: JSValue?)
    func warning(_ message: String, _ metadata: JSValue?)
    func error(_ message: String, _ metadata: JSValue?)
}

@objc protocol SystemBridgeNamespaceExport: JSExport {
    func appVersion() -> String
}

@MainActor
@objcMembers
final class BrowserBridgeNamespace: NSObject, BrowserBridgeNamespaceExport {
    private struct Entry {
        let task: Task<Void, Never>
        let resolve: JSValue
        let reject: JSValue
        let browserId: String?
        let operation: String
    }

    let version = BrowserBridgeService.apiVersion
    private let service: BrowserBridgeService
    private let mapper: BrowserBridgeErrorMapper
    private let codec = BridgeValueCodec()
    private var entries: [String: Entry] = [:]
    private var stopped = false

    init(service: BrowserBridgeService, mapper: BrowserBridgeErrorMapper = BrowserBridgeErrorMapper()) {
        self.service = service
        self.mapper = mapper
    }

    func invoke(_ method: String, _ payloadJSON: String) -> JSValue {
        guard let context = JSContext.current() else { return JSValue(undefinedIn: nil) }
        let operationId = UUID().uuidString
        guard !stopped, entries.count < service.pendingLimit else {
            return rejectedPromise(
                context: context,
                error: StructuredBridgeError(
                    name: "BridgeError", code: stopped ? .cancelled : .invalidState,
                    message: stopped ? "Runtime is stopping." : "Pending Promise limit reached.",
                    operationId: operationId, browserId: nil, operation: method,
                    retryable: false, details: [:]
                )
            )
        }
        guard let holder = context.evaluateScript(
            "(function(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return {promise,resolve,reject};})()"
        ), let promise = holder.forProperty("promise"),
           let resolve = holder.forProperty("resolve"),
           let reject = holder.forProperty("reject") else {
            return JSValue(undefinedIn: context)
        }
        promise.setValue(operationId, forProperty: "operationId")
        let browserId = Self.extractBrowserId(payloadJSON)
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let resultJSON = try await self.service.perform(method: method, payloadJSON: payloadJSON)
                self.resolve(operationId, json: resultJSON)
                if method == "destroy", let browserId {
                    self.cancel(browserId: browserId, excluding: operationId)
                }
            } catch {
                self.reject(operationId, error: self.mapper.map(
                    error, operationId: operationId, browserId: browserId, operation: method
                ))
            }
        }
        entries[operationId] = Entry(
            task: task, resolve: resolve, reject: reject,
            browserId: browserId, operation: method
        )
        return promise
    }

    func cancel(_ operationId: String) -> Bool {
        guard let entry = entries.removeValue(forKey: operationId) else { return false }
        entry.task.cancel()
        let error = StructuredBridgeError(
            name: "BrowserError", code: .cancelled, message: "Bridge operation cancelled.",
            operationId: operationId, browserId: entry.browserId, operation: entry.operation,
            retryable: false, details: [:]
        )
        entry.reject.call(withArguments: [object(error, context: entry.reject.context)])
        return true
    }

    func capabilities() -> JSValue {
        guard let context = JSContext.current() else { return JSValue(undefinedIn: nil) }
        return object(BrowserBridgeCapabilities(), context: context)
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        for id in Array(entries.keys) { _ = cancel(id) }
        service.stop()
    }

    func prepareForStart() {
        stopped = false
    }

    private func resolve(_ operationId: String, json: String) {
        guard let entry = entries.removeValue(forKey: operationId),
              let data = json.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return
        }
        entry.resolve.call(withArguments: [value is NSNull ? NSNull() : value])
    }

    private func reject(_ operationId: String, error: StructuredBridgeError) {
        guard let entry = entries.removeValue(forKey: operationId) else { return }
        entry.reject.call(withArguments: [object(error, context: entry.reject.context)])
    }

    private func cancel(browserId: String, excluding operationId: String) {
        let ids = entries.compactMap { id, entry in
            entry.browserId == browserId && id != operationId ? id : nil
        }
        ids.forEach { _ = cancel($0) }
    }

    private func rejectedPromise(context: JSContext, error: StructuredBridgeError) -> JSValue {
        let promise = context.evaluateScript("Promise.reject")!
        return promise.call(withArguments: [object(error, context: context)])
    }

    private func object<T: Encodable>(_ value: T, context: JSContext?) -> Any {
        guard let context,
              let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data) else { return NSNull() }
        return JSValue(object: object, in: context) ?? NSNull()
    }

    private static func extractBrowserId(_ payloadJSON: String) -> String? {
        guard let data = payloadJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let args = object["args"] as? [Any],
              let first = args.first as? String else { return nil }
        return first
    }
}

@objcMembers final class StorageBridgeNamespace: NSObject, StorageBridgeNamespaceExport {}
@objcMembers final class NetworkBridgeNamespace: NSObject, NetworkBridgeNamespaceExport {}
@objcMembers final class NotificationBridgeNamespace: NSObject, NotificationBridgeNamespaceExport {}
@objcMembers final class DeviceBridgeNamespace: NSObject, DeviceBridgeNamespaceExport {}
@objcMembers final class EventsBridgeNamespace: NSObject, EventsBridgeNamespaceExport {}

@objcMembers
final class LoggerBridgeNamespace: NSObject, LoggerBridgeNamespaceExport {
    private let logger: Logging
    private let redactor: BrowserRedactor
    private let maximumMessageLength = 4_096

    init(logger: Logging, redactor: BrowserRedactor = BrowserRedactor()) {
        self.logger = logger
        self.redactor = redactor
    }

    func log(_ level: String, _ message: String) { write(level, message, nil) }
    func debug(_ message: String, _ metadata: JSValue?) { write("debug", message, metadata) }
    func info(_ message: String, _ metadata: JSValue?) { write("info", message, metadata) }
    func warning(_ message: String, _ metadata: JSValue?) { write("warning", message, metadata) }
    func error(_ message: String, _ metadata: JSValue?) { write("error", message, metadata) }

    private func write(_ level: String, _ message: String, _ metadata: JSValue?) {
        let safeMessage = String(message.prefix(maximumMessageLength))
        let raw = metadata?.toDictionary() as? [String: Any] ?? [:]
        let strings = Dictionary(uniqueKeysWithValues: raw.prefix(32).map {
            (String($0.key.prefix(100)), String(describing: $0.value).prefix(500).description)
        })
        logger.log(
            LogLevel(rawValue: level.lowercased()) ?? .info,
            category: .runtime, message: safeMessage, metadata: redactor.redact(strings)
        )
    }
}

@objcMembers
final class SystemBridgeNamespace: NSObject, SystemBridgeNamespaceExport {
    func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
