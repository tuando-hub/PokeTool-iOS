import Foundation
import JavaScriptCore

@objc protocol NativeBridgeExport: JSExport {
    var Browser: BrowserBridgeNamespace { get }
    var Storage: InfrastructureBridgeNamespace { get }
    var Keychain: InfrastructureBridgeNamespace { get }
    var Logger: LoggerBridgeNamespace { get }
    var Network: InfrastructureBridgeNamespace { get }
    var System: InfrastructureBridgeNamespace { get }
    var Notification: InfrastructureBridgeNamespace { get }
    var Device: InfrastructureBridgeNamespace { get }
    var Events: InfrastructureBridgeNamespace { get }
    var Runtime: RuntimeBridgeNamespace { get }
    var PhoneOtp: InfrastructureBridgeNamespace { get }
}

@objcMembers
@MainActor
final class NativeBridge: NSObject, NativeBridgeExport {
    let Browser: BrowserBridgeNamespace
    let Storage: InfrastructureBridgeNamespace
    let Keychain: InfrastructureBridgeNamespace
    let Logger: LoggerBridgeNamespace
    let Network: InfrastructureBridgeNamespace
    let System: InfrastructureBridgeNamespace
    let Notification: InfrastructureBridgeNamespace
    let Device: InfrastructureBridgeNamespace
    let Events: InfrastructureBridgeNamespace
    let Runtime: RuntimeBridgeNamespace
    let PhoneOtp: InfrastructureBridgeNamespace

    init(
        Browser: BrowserBridgeNamespace,
        Storage: InfrastructureBridgeNamespace,
        Keychain: InfrastructureBridgeNamespace,
        Logger: LoggerBridgeNamespace,
        Network: InfrastructureBridgeNamespace,
        System: InfrastructureBridgeNamespace,
        Notification: InfrastructureBridgeNamespace,
        Device: InfrastructureBridgeNamespace,
        Events: InfrastructureBridgeNamespace,
        Runtime: RuntimeBridgeNamespace, PhoneOtp: InfrastructureBridgeNamespace
    ) {
        self.Browser = Browser
        self.Storage = Storage
        self.Keychain = Keychain
        self.Logger = Logger
        self.Network = Network
        self.System = System
        self.Notification = Notification
        self.Device = Device
        self.Events = Events
        self.Runtime = Runtime
        self.PhoneOtp = PhoneOtp
    }

    func stop() {
        Browser.stop()
        Storage.stop()
        Keychain.stop()
        Network.stop()
        System.stop()
        Notification.stop()
        Device.stop()
        Events.stop()
        Runtime.stop()
        PhoneOtp.stop()
    }

    func prepareForStart() {
        Browser.prepareForStart()
        Storage.prepareForStart()
        Keychain.prepareForStart()
        Network.prepareForStart()
        System.prepareForStart()
        Notification.prepareForStart()
        Device.prepareForStart()
        Events.prepareForStart()
        Runtime.prepareForStart()
        PhoneOtp.prepareForStart()
    }
}

@MainActor
final class NativeBridgeFactory {
    private let logger: Logging
    private let browserManager: BrowserManager
    private let fileStore: FileStore
    private let networkClient: NetworkClient
    private let keychainStore: KeychainStore
    private let notificationService: NotificationService
    private let eventBus: EventBus
    private let deviceInfo: DeviceInformationProviding

    init(
        logger: Logging, browserManager: BrowserManager, fileStore: FileStore,
        networkClient: NetworkClient, keychainStore: KeychainStore,
        notificationService: NotificationService, eventBus: EventBus,
        deviceInfo: DeviceInformationProviding
    ) {
        self.logger = logger
        self.browserManager = browserManager
        self.fileStore = fileStore
        self.networkClient = networkClient
        self.keychainStore = keychainStore
        self.notificationService = notificationService
        self.eventBus = eventBus
        self.deviceInfo = deviceInfo
    }

    func makeBridge() -> NativeBridge {
        let limits = JavaScriptModuleLimits()
        let resolver = JavaScriptModuleResolver(limits: limits)
        let infrastructureLimits = InfrastructureResourceLimits()
        let runtimeID = UUID().uuidString
        let phoneConfiguration = PhoneGatewayConfiguration(keychain: keychainStore)
        let runtimeNamespace = RuntimeBridgeNamespace(
            resolver: resolver,
            sourceProvider: BundleJavaScriptModuleSourceProvider(
                bundle: .main, limits: limits
            ),
            limits: limits,
            logger: logger,
            runtimeID: runtimeID
        )
        return NativeBridge(
            Browser: BrowserBridgeNamespace(
                service: BrowserBridgeService(browserManager: browserManager)
            ),
            Storage: InfrastructureBridgeNamespace(
                service: StorageBridgeService(store: fileStore, limits: infrastructureLimits),
                runtimeID: runtimeID, limits: infrastructureLimits
            ),
            Keychain: InfrastructureBridgeNamespace(
                service: KeychainBridgeService(store: keychainStore, limits: infrastructureLimits),
                runtimeID: runtimeID, limits: infrastructureLimits
            ),
            Logger: LoggerBridgeNamespace(logger: logger),
            Network: InfrastructureBridgeNamespace(
                service: NetworkBridgeService(client: networkClient, limits: infrastructureLimits),
                runtimeID: runtimeID, limits: infrastructureLimits
            ),
            System: InfrastructureBridgeNamespace(
                service: SystemInfrastructureBridgeService(limits: infrastructureLimits),
                runtimeID: runtimeID, limits: infrastructureLimits
            ),
            Notification: InfrastructureBridgeNamespace(
                service: NotificationBridgeService(
                    notifications: notificationService, limits: infrastructureLimits
                ),
                runtimeID: runtimeID, limits: infrastructureLimits
            ),
            Device: InfrastructureBridgeNamespace(
                service: DeviceBridgeService(provider: deviceInfo),
                runtimeID: runtimeID, limits: infrastructureLimits
            ),
            Events: InfrastructureBridgeNamespace(
                service: EventsBridgeService(eventBus: eventBus),
                runtimeID: runtimeID, limits: infrastructureLimits
            ),
            Runtime: runtimeNamespace,
            PhoneOtp: InfrastructureBridgeNamespace(service: PhoneOtpBridgeService(configuration: phoneConfiguration), runtimeID: runtimeID, limits: infrastructureLimits)
        )
    }
}
