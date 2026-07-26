import Foundation

@MainActor
final class DependencyContainer {
    let appStateStore: AppStateStore
    let eventBus: EventBus
    let logger: Logging
    let browserMetrics: BrowserMetricsCollector
    let userAgentManager: UserAgentManager
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
        browserMetrics = BrowserMetricsCollector()
        userAgentManager = UserAgentManager()

        let browserEventEmitter = BrowserEventEmitter(eventBus: eventBus)
        let browserConfiguration = BrowserEngineConfiguration.default
        let browserPool = BrowserPool(
            maximumSessions: browserConfiguration.maximumConcurrentSessions
        )
        let browserSessionFactory = BrowserSessionFactory(
            userAgentManager: userAgentManager,
            eventEmitter: browserEventEmitter,
            logger: logger,
            metrics: browserMetrics
        )
        browserManager = BrowserManager(
            pool: browserPool,
            sessionFactory: browserSessionFactory,
            userAgentManager: userAgentManager,
            eventEmitter: browserEventEmitter,
            metrics: browserMetrics,
            logger: logger
        )
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
