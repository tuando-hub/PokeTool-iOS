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
        let operationCoordinator = BrowserOperationCoordinator(
            eventEmitter: browserEventEmitter,
            metrics: browserMetrics
        )
        let javaScriptOperations = BrowserJavaScriptOperations()
        let navigationOperations = BrowserNavigationOperations()
        let domOperations = BrowserDOMOperations(javaScript: javaScriptOperations)
        let elementOperations = BrowserElementOperations(javaScript: javaScriptOperations)
        let captureOperations = BrowserCaptureOperations(
            destinations: ControlledScreenshotDestinationPolicy()
        )
        let browserConfiguration = BrowserEngineConfiguration.default
        let browserPool = BrowserPool(
            maximumSessions: browserConfiguration.maximumConcurrentSessions
        )
        let browserSessionFactory = BrowserSessionFactory(
            userAgentManager: userAgentManager,
            eventEmitter: browserEventEmitter,
            logger: logger,
            metrics: browserMetrics,
            operationCoordinator: operationCoordinator
        )
        browserManager = BrowserManager(
            pool: browserPool,
            sessionFactory: browserSessionFactory,
            userAgentManager: userAgentManager,
            eventEmitter: browserEventEmitter,
            metrics: browserMetrics,
            logger: logger,
            coordinator: operationCoordinator,
            navigationOperations: navigationOperations,
            javaScriptOperations: javaScriptOperations,
            domOperations: domOperations,
            elementOperations: elementOperations,
            captureOperations: captureOperations
        )
        fileStore = FileStore()
        networkClient = NetworkClient()
        keychainStore = KeychainStore()
        backgroundService = BackgroundService()
        notificationService = NotificationService()

        let bridgeFactory = NativeBridgeFactory(
            logger: logger,
            browserManager: browserManager
        )
        runtimeFactory = JavaScriptRuntimeFactory(
            bridgeFactory: bridgeFactory,
            logger: logger
        )
    }
}
