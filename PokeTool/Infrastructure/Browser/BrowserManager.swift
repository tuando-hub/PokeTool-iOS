import Foundation
import WebKit

@MainActor
final class BrowserManager {
    private let pool: BrowserPool
    private let eventBus: EventBus
    private let logger: Logging

    init(
        eventBus: EventBus,
        logger: Logging
    ) {
        self.pool = BrowserPool()
        self.eventBus = eventBus
        self.logger = logger
    }

    @discardableResult
    func createBrowser(
        metadata: BrowserMetadata,
        userAgent: String? = nil
    ) -> BrowserID {
        let browserId = BrowserID()
        let session = BrowserSession(
            browserId: browserId,
            metadata: metadata,
            userAgent: userAgent
        )
        pool.insert(session)
        logger.log(
            .info,
            category: .browser,
            message: "Browser session created",
            metadata: ["browserId": browserId.description]
        )
        eventBus.publish(
            PlatformEvent(
                name: "browser.created",
                source: .browser,
                correlationID: browserId.description
            )
        )
        return browserId
    }

    func snapshot(for browserId: BrowserID) -> BrowserSnapshot? {
        pool.session(for: browserId)?.snapshot
    }

    func allSnapshots() -> [BrowserSnapshot] {
        pool.browserIDs.compactMap { pool.session(for: $0)?.snapshot }
    }

    func presentationWebView(for browserId: BrowserID) -> WKWebView? {
        pool.session(for: browserId)?.webView
    }

    func destroyBrowser(_ browserId: BrowserID) {
        guard let session = pool.remove(browserId: browserId) else { return }
        session.prepareForDestruction()
        logger.log(
            .info,
            category: .browser,
            message: "Browser session destroyed",
            metadata: ["browserId": browserId.description]
        )
        eventBus.publish(
            PlatformEvent(
                name: "browser.destroyed",
                source: .browser,
                correlationID: browserId.description
            )
        )
    }

    func destroyAllBrowsers() {
        pool.removeAll().forEach { $0.prepareForDestruction() }
    }
}
