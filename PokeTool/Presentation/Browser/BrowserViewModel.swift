import Foundation
import UIKit
import WebKit

@MainActor
final class BrowserViewModel {
    private let browserManager: BrowserManager
    private(set) var browserId: BrowserID?

    init(browserManager: BrowserManager) { self.browserManager = browserManager }

    func webView() throws -> WKWebView {
        if let browserId { return try browserManager.presentationWebView(for: browserId) }
        let id = try browserManager.createSession(configuration: .presentation)
        browserId = id
        return try browserManager.presentationWebView(for: id)
    }

    func load(_ text: String) async throws {
        guard let browserId else { throw BrowserError.unknown("Presentation session is not created") }
        let normalized = text.contains("://") ? text : "https://\(text)"
        guard let url = URL(string: normalized) else { throw BrowserError.invalidURL(text) }
        try await browserManager.load(url, in: browserId)
    }

    func reload() async throws { try await withID { try await browserManager.reload($0) } }
    func stop() throws { try browserManager.stopLoading(requireID()) }
    func back() throws { try browserManager.goBack(requireID()) }
    func forward() throws { try browserManager.goForward(requireID()) }
    func snapshot() throws -> BrowserSnapshot { try browserManager.snapshot(for: requireID()) }

    #if DEBUG
    func evaluate(_ source: String) async throws -> BrowserValue {
        try await browserManager.evaluateJavaScript(source, in: requireID())
    }
    func selectorExists(_ selector: String) async throws -> Bool {
        try await browserManager.elementExists(selector, in: requireID())
    }
    func screenshot() async throws -> BrowserScreenshotResult {
        try await browserManager.captureScreenshot(in: requireID())
    }
    #endif

    func updateViewport(size: CGSize, safeAreaInsets: UIEdgeInsets, scale: CGFloat) {
        guard let browserId else { return }
        try? browserManager.updateViewport(
            size: size, safeAreaInsets: safeAreaInsets, scale: scale, for: browserId
        )
    }

    private func requireID() throws -> BrowserID {
        guard let browserId else { throw BrowserError.unknown("Presentation session is not created") }
        return browserId
    }

    private func withID(_ body: (BrowserID) async throws -> Void) async throws {
        try await body(requireID())
    }
}
