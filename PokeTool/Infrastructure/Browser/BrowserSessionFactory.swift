import Foundation
import WebKit

@MainActor
final class BrowserSessionFactory {
    private let userAgentManager: UserAgentManager
    private let eventEmitter: BrowserEventEmitter
    private let logger: Logging
    private let metrics: BrowserMetricsCollector

    init(
        userAgentManager: UserAgentManager,
        eventEmitter: BrowserEventEmitter,
        logger: Logging,
        metrics: BrowserMetricsCollector
    ) {
        self.userAgentManager = userAgentManager
        self.eventEmitter = eventEmitter
        self.logger = logger
        self.metrics = metrics
    }

    func makeSession(
        browserId: BrowserID,
        configuration: BrowserSessionConfiguration
    ) -> BrowserSession {
        let dataStore: WKWebsiteDataStore
        switch configuration.dataStorePolicy {
        case .isolated:
            dataStore = .nonPersistent()
        case .shared:
            dataStore = .default()
        }

        let processPool = WKProcessPool()
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = dataStore
        webConfiguration.processPool = processPool
        webConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true

        let userAgent = userAgentManager.resolve(configuration.userAgent)
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.customUserAgent = userAgent

        let cookieManager = CookieManager(
            browserId: browserId,
            cookieStore: dataStore.httpCookieStore,
            eventEmitter: eventEmitter,
            logger: logger
        )
        let storageManager = StorageManager(
            browserId: browserId,
            websiteDataStore: dataStore,
            eventEmitter: eventEmitter,
            logger: logger
        )
        let downloadManager = DownloadManager(
            browserId: browserId,
            eventEmitter: eventEmitter
        )

        return BrowserSession(
            browserId: browserId,
            metadata: configuration.metadata,
            userAgent: userAgent,
            viewport: configuration.viewport,
            webView: webView,
            websiteDataStore: dataStore,
            processPool: processPool,
            cookieManager: cookieManager,
            storageManager: storageManager,
            downloadManager: downloadManager,
            eventEmitter: eventEmitter,
            logger: logger,
            metrics: metrics
        )
    }
}
