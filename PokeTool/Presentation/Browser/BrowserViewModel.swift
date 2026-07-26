import Foundation
import UIKit
import WebKit

@MainActor
final class BrowserViewModel {
    private let browserManager: BrowserManager
    private var browserId: BrowserID?

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    func webView() throws -> WKWebView {
        if let browserId,
           let webView = try? browserManager.presentationWebView(for: browserId) {
            return webView
        }

        let id = try browserManager.createSession(configuration: .presentation)
        browserId = id
        return try browserManager.presentationWebView(for: id)
    }

    func updateViewport(
        size: CGSize,
        safeAreaInsets: UIEdgeInsets,
        scale: CGFloat
    ) {
        guard let browserId else { return }
        try? browserManager.updateViewport(
            size: size,
            safeAreaInsets: safeAreaInsets,
            scale: scale,
            for: browserId
        )
    }
}
