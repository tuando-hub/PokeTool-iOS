import Foundation
import JavaScriptCore

@objc protocol NativeBridgeExport: JSExport {
    var Browser: BrowserBridgeNamespace { get }
    var Storage: StorageBridgeNamespace { get }
    var Logger: LoggerBridgeNamespace { get }
    var Network: NetworkBridgeNamespace { get }
    var System: SystemBridgeNamespace { get }
    var Notification: NotificationBridgeNamespace { get }
    var Device: DeviceBridgeNamespace { get }
    var Events: EventsBridgeNamespace { get }
    var Runtime: RuntimeBridgeNamespace { get }
}

@objcMembers
@MainActor
final class NativeBridge: NSObject, NativeBridgeExport {
    let Browser: BrowserBridgeNamespace
    let Storage: StorageBridgeNamespace
    let Logger: LoggerBridgeNamespace
    let Network: NetworkBridgeNamespace
    let System: SystemBridgeNamespace
    let Notification: NotificationBridgeNamespace
    let Device: DeviceBridgeNamespace
    let Events: EventsBridgeNamespace
    let Runtime: RuntimeBridgeNamespace

    init(
        Browser: BrowserBridgeNamespace,
        Storage: StorageBridgeNamespace,
        Logger: LoggerBridgeNamespace,
        Network: NetworkBridgeNamespace,
        System: SystemBridgeNamespace,
        Notification: NotificationBridgeNamespace,
        Device: DeviceBridgeNamespace,
        Events: EventsBridgeNamespace,
        Runtime: RuntimeBridgeNamespace
    ) {
        self.Browser = Browser
        self.Storage = Storage
        self.Logger = Logger
        self.Network = Network
        self.System = System
        self.Notification = Notification
        self.Device = Device
        self.Events = Events
        self.Runtime = Runtime
    }

    func stop() {
        Browser.stop()
        Runtime.stop()
    }

    func prepareForStart() {
        Browser.prepareForStart()
        Runtime.prepareForStart()
    }
}

@MainActor
final class NativeBridgeFactory {
    private let logger: Logging
    private let browserManager: BrowserManager

    init(logger: Logging, browserManager: BrowserManager) {
        self.logger = logger
        self.browserManager = browserManager
    }

    func makeBridge() -> NativeBridge {
        let limits = JavaScriptModuleLimits()
        let resolver = JavaScriptModuleResolver(limits: limits)
        return NativeBridge(
            Browser: BrowserBridgeNamespace(
                service: BrowserBridgeService(browserManager: browserManager)
            ),
            Storage: StorageBridgeNamespace(),
            Logger: LoggerBridgeNamespace(logger: logger),
            Network: NetworkBridgeNamespace(),
            System: SystemBridgeNamespace(),
            Notification: NotificationBridgeNamespace(),
            Device: DeviceBridgeNamespace(),
            Events: EventsBridgeNamespace(),
            Runtime: RuntimeBridgeNamespace(
                resolver: resolver,
                sourceProvider: BundleJavaScriptModuleSourceProvider(
                    bundle: .main, limits: limits
                ),
                limits: limits,
                logger: logger
            )
        )
    }
}
