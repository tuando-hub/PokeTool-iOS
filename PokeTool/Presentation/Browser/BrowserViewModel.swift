import Foundation
import WebKit

final class BrowserViewModel {
    private let browserService: WebViewAutomationService

    init(browserService: WebViewAutomationService) {
        self.browserService = browserService
    }

    @MainActor
    func webView() -> WKWebView {
        browserService.visibleWebView
    }
}

