import Foundation
import WebKit

@MainActor
final class BrowserSession {
    let browserId: BrowserID
    let webView: WKWebView
    let websiteDataStore: WKWebsiteDataStore
    let cookieStore: WKHTTPCookieStore

    private(set) var loadingState: BrowserLoadingState = .idle
    private(set) var navigationState: BrowserNavigationState = .initial
    private(set) var metadata: BrowserMetadata
    private(set) var userAgent: String?

    init(
        browserId: BrowserID,
        metadata: BrowserMetadata,
        userAgent: String? = nil,
        websiteDataStore: WKWebsiteDataStore = .default()
    ) {
        self.browserId = browserId
        self.metadata = metadata
        self.userAgent = userAgent
        self.websiteDataStore = websiteDataStore
        self.cookieStore = websiteDataStore.httpCookieStore

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = userAgent
        self.webView = webView
    }

    var snapshot: BrowserSnapshot {
        BrowserSnapshot(
            browserId: browserId,
            loadingState: loadingState,
            navigationState: navigationState,
            metadata: metadata,
            userAgent: userAgent
        )
    }

    func updateMetadata(_ metadata: BrowserMetadata) {
        self.metadata = metadata
    }

    func updateUserAgent(_ userAgent: String?) {
        self.userAgent = userAgent
        webView.customUserAgent = userAgent
    }

    func prepareForDestruction() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
}

