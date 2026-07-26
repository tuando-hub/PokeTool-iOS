import Foundation
import JavaScriptCore

@objc protocol BrowserBridgeNamespaceExport: JSExport {}
@objc protocol StorageBridgeNamespaceExport: JSExport {}
@objc protocol NetworkBridgeNamespaceExport: JSExport {}
@objc protocol NotificationBridgeNamespaceExport: JSExport {}
@objc protocol DeviceBridgeNamespaceExport: JSExport {}
@objc protocol EventsBridgeNamespaceExport: JSExport {}

@objc protocol LoggerBridgeNamespaceExport: JSExport {
    func log(_ level: String, _ message: String)
}

@objc protocol SystemBridgeNamespaceExport: JSExport {
    func appVersion() -> String
}

@objcMembers
final class BrowserBridgeNamespace: NSObject, BrowserBridgeNamespaceExport {}

@objcMembers
final class StorageBridgeNamespace: NSObject, StorageBridgeNamespaceExport {}

@objcMembers
final class NetworkBridgeNamespace: NSObject, NetworkBridgeNamespaceExport {}

@objcMembers
final class NotificationBridgeNamespace: NSObject, NotificationBridgeNamespaceExport {}

@objcMembers
final class DeviceBridgeNamespace: NSObject, DeviceBridgeNamespaceExport {}

@objcMembers
final class EventsBridgeNamespace: NSObject, EventsBridgeNamespaceExport {}

@objcMembers
final class LoggerBridgeNamespace: NSObject, LoggerBridgeNamespaceExport {
    private let logger: Logging

    init(logger: Logging) {
        self.logger = logger
    }

    func log(_ level: String, _ message: String) {
        logger.log(
            LogLevel(rawValue: level.lowercased()) ?? .info,
            category: .bridge,
            message: message
        )
    }
}

@objcMembers
final class SystemBridgeNamespace: NSObject, SystemBridgeNamespaceExport {
    func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
