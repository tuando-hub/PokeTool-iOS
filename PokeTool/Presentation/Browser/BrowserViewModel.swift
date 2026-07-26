import Foundation
import WebKit

@MainActor
final class BrowserViewModel {
    private let browserManager: BrowserManager
    private var browserId: BrowserID?

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    func webView() -> WKWebView {
        if let browserId,
           let webView = browserManager.presentationWebView(for: browserId) {
            return webView
        }

        let id = browserManager.createBrowser(metadata: .presentation)
        browserId = id
        return browserManager.presentationWebView(for: id) ?? WKWebView()
    }
}
