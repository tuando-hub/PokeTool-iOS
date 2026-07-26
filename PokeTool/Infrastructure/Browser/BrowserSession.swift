import Foundation
import WebKit

@MainActor
final class BrowserSession: NSObject {
    let browserId: BrowserID
    let webView: WKWebView
    let websiteDataStore: WKWebsiteDataStore
    let cookieStore: WKHTTPCookieStore
    let processPool: WKProcessPool
    let cookieManager: CookieManager
    let storageManager: StorageManager
    let downloadManager: DownloadManager
    let createdAt: Date

    private(set) var state: BrowserState = .creating
    private(set) var loadingState: BrowserLoadingState = .idle
    private(set) var navigationState: BrowserNavigationState = .initial
    private(set) var history = BrowserHistory()
    private(set) var metadata: BrowserMetadata
    private(set) var userAgent: String?
    private(set) var viewport: BrowserViewport
    private(set) var currentURL: URL?
    private(set) var previousURL: URL?
    private(set) var pageTitle: String?
    private(set) var estimatedProgress: Double = 0
    private(set) var navigationType: BrowserNavigationType = .unknown

    private let eventEmitter: BrowserEventEmitter
    private let logger: Logging
    private let metrics: BrowserMetricsCollector
    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var loadStartedAt: Date?

    init(
        browserId: BrowserID,
        metadata: BrowserMetadata,
        userAgent: String?,
        viewport: BrowserViewport,
        webView: WKWebView,
        websiteDataStore: WKWebsiteDataStore,
        processPool: WKProcessPool,
        cookieManager: CookieManager,
        storageManager: StorageManager,
        downloadManager: DownloadManager,
        eventEmitter: BrowserEventEmitter,
        logger: Logging,
        metrics: BrowserMetricsCollector
    ) {
        self.browserId = browserId
        self.metadata = metadata
        self.userAgent = userAgent
        self.viewport = viewport
        self.webView = webView
        self.websiteDataStore = websiteDataStore
        self.cookieStore = websiteDataStore.httpCookieStore
        self.processPool = processPool
        self.cookieManager = cookieManager
        self.storageManager = storageManager
        self.downloadManager = downloadManager
        self.eventEmitter = eventEmitter
        self.logger = logger
        self.metrics = metrics
        self.createdAt = Date()

        super.init()

        webView.navigationDelegate = self
        installObservations()
        transition(to: .idle)
    }

    var snapshot: BrowserSnapshot {
        BrowserSnapshot(
            browserId: browserId,
            state: state,
            loadingState: loadingState,
            navigationState: navigationState,
            navigation: BrowserNavigationSnapshot(
                currentURL: currentURL,
                previousURL: previousURL,
                title: pageTitle,
                estimatedProgress: estimatedProgress,
                navigationType: navigationType,
                history: history
            ),
            metadata: metadata,
            userAgent: userAgent,
            viewport: viewport,
            downloadState: downloadManager.summary,
            storageState: storageManager.state,
            createdAt: createdAt
        )
    }

    func updateMetadata(_ metadata: BrowserMetadata) {
        self.metadata = metadata
    }

    func updateUserAgent(_ userAgent: String?) {
        self.userAgent = userAgent
        webView.customUserAgent = userAgent
    }

    func updateViewport(_ viewport: BrowserViewport) {
        self.viewport = viewport
    }

    func shutdown(clearData: Bool) async {
        guard state != .destroyed else { return }
        transition(to: .stopping)
        webView.stopLoading()
        downloadManager.cancelAll()

        if clearData {
            await cookieManager.clear()
            await storageManager.clear(.all)
        }

        cookieManager.stopObserving()
        progressObservation?.invalidate()
        titleObservation?.invalidate()
        progressObservation = nil
        titleObservation = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        transition(to: .destroyed)
    }

    private func installObservations() {
        progressObservation = webView.observe(
            \.estimatedProgress,
            options: [.initial, .new]
        ) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.estimatedProgress = change.newValue ?? 0
            }
        }

        titleObservation = webView.observe(
            \.title,
            options: [.new]
        ) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.pageTitle = change.newValue ?? nil
            }
        }
    }

    private func transition(to nextState: BrowserState) {
        guard state != nextState else { return }
        guard Self.allowedTransitions[state, default: []].contains(nextState) else {
            logger.log(
                .error,
                category: .browser,
                message: BrowserError.invalidState(from: state, to: nextState).localizedDescription,
                metadata: ["browserId": browserId.description]
            )
            return
        }
        state = nextState
        eventEmitter.emit(.stateChanged(browserId, nextState))
    }

    private func beginLoading(url: URL?) {
        previousURL = currentURL
        currentURL = url
        loadStartedAt = Date()
        loadingState = .loading(startedAt: loadStartedAt ?? Date())
        navigationState = .provisional
        transition(to: .loading)
        eventEmitter.emit(.loadingStarted(browserId))
        eventEmitter.emit(.navigationStarted(browserId, url))
    }

    private func completeLoading() {
        let duration = Date().timeIntervalSince(loadStartedAt ?? Date())
        currentURL = webView.url
        pageTitle = webView.title
        estimatedProgress = webView.estimatedProgress
        loadingState = .finished(duration: duration)
        navigationState = .completed

        if let currentURL {
            history.append(
                BrowserHistoryEntry(
                    url: currentURL,
                    title: pageTitle,
                    visitedAt: Date(),
                    navigationType: navigationType
                )
            )
            eventEmitter.emit(.historyChanged(browserId, history.entries.count))
        }

        transition(to: .ready)
        metrics.navigationFinished(browserId: browserId, duration: duration)
        eventEmitter.emit(.loadingFinished(browserId, duration))
        eventEmitter.emit(.navigationFinished(browserId, currentURL))
        Task { @MainActor [weak self] in
            guard let self, self.state != .stopping, self.state != .destroyed else { return }
            _ = await self.storageManager.inspect()
        }
    }

    private func failLoading(_ error: Error) {
        let nsError = error as NSError
        let browserError = BrowserError.navigationFailed(
            code: nsError.code,
            message: nsError.localizedDescription
        )
        loadingState = .failed(browserError)
        navigationState = .failed(browserError)
        transition(to: .idle)
        eventEmitter.emit(.navigationFailed(browserId, browserError))
    }

    private static let allowedTransitions: [BrowserState: Set<BrowserState>] = [
        .creating: [.idle, .stopping],
        .idle: [.loading, .busy, .stopping],
        .loading: [.interactive, .ready, .idle, .stopping],
        .interactive: [.ready, .loading, .idle, .stopping],
        .ready: [.loading, .busy, .idle, .stopping],
        .busy: [.ready, .loading, .idle, .stopping],
        .stopping: [.destroyed],
        .destroyed: []
    ]
}

extension BrowserSession: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        navigationType = BrowserNavigationType(navigationAction.navigationType)
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        beginLoading(url: webView.url)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        navigationState = .committed
        transition(to: .interactive)
        eventEmitter.emit(.navigationCommitted(browserId, webView.url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        completeLoading()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        failLoading(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        failLoading(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        navigationState = .processTerminated
        loadingState = .failed(.webProcessTerminated)
        transition(to: .idle)
        metrics.webProcessTerminated(browserId: browserId)
        eventEmitter.emit(.webProcessTerminated(browserId))
    }
}

private extension BrowserNavigationType {
    init(_ nativeType: WKNavigationType) {
        switch nativeType {
        case .linkActivated: self = .linkActivated
        case .formSubmitted: self = .formSubmitted
        case .backForward: self = .backForward
        case .reload: self = .reload
        case .formResubmitted: self = .formResubmitted
        case .other: self = .other
        @unknown default: self = .unknown
        }
    }
}
