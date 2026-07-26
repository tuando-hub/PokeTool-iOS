import Foundation

final class DependencyContainer {
    let appStateStore: AppStateStore
    let browserService: WebViewAutomationService
    let javaScriptRuntime: JavaScriptRuntime
    let fileStore: FileStore
    let networkClient: NetworkClient
    let keychainStore: KeychainStore
    let backgroundService: BackgroundService
    let notificationService: NotificationService

    init() {
        appStateStore = AppStateStore()
        browserService = WebViewAutomationService()
        fileStore = FileStore()
        networkClient = NetworkClient()
        keychainStore = KeychainStore()
        backgroundService = BackgroundService()
        notificationService = NotificationService()

        let bridge = NativeBridge(
            browser: browserService,
            fileStore: fileStore,
            network: networkClient,
            keychain: keychainStore
        )
        javaScriptRuntime = JavaScriptRuntime(bridge: bridge)
    }
}

