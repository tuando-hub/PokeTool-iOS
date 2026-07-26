import Foundation

@MainActor
final class DependencyContainer {
    let appStateStore: AppStateStore
    let eventBus: EventBus
    let logger: Logging
    let browserManager: BrowserManager
    let runtimeFactory: BusinessRuntimeFactory
    let fileStore: FileStore
    let networkClient: NetworkClient
    let keychainStore: KeychainStore
    let backgroundService: BackgroundService
    let notificationService: NotificationService

    init() {
        appStateStore = AppStateStore()
        eventBus = NativeEventBus()
        logger = UnifiedLogger()
        browserManager = BrowserManager(eventBus: eventBus, logger: logger)
        fileStore = FileStore()
        networkClient = NetworkClient()
        keychainStore = KeychainStore()
        backgroundService = BackgroundService()
        notificationService = NotificationService()

        let bridgeFactory = NativeBridgeFactory(logger: logger)
        runtimeFactory = JavaScriptRuntimeFactory(
            bridgeFactory: bridgeFactory,
            logger: logger
        )
    }
}
