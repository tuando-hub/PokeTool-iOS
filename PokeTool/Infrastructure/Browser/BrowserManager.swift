import Foundation
import UIKit
import WebKit

enum BrowserCleanupPolicy: Equatable {
    case discardSession
    case clearWebsiteData
}

@MainActor
final class BrowserManager {
    private let pool: BrowserPool
    private let sessionFactory: BrowserSessionFactory
    private let userAgentManager: UserAgentManager
    private let eventEmitter: BrowserEventEmitter
    private let metrics: BrowserMetricsCollector
    private let logger: Logging
    private let coordinator: BrowserOperationCoordinator
    private let navigationOperations: BrowserNavigationOperations
    private let javaScriptOperations: BrowserJavaScriptOperations
    private let domOperations: BrowserDOMOperations
    private let elementOperations: BrowserElementOperations
    private let captureOperations: BrowserCaptureOperations

    init(
        pool: BrowserPool,
        sessionFactory: BrowserSessionFactory,
        userAgentManager: UserAgentManager,
        eventEmitter: BrowserEventEmitter,
        metrics: BrowserMetricsCollector,
        logger: Logging,
        coordinator: BrowserOperationCoordinator,
        navigationOperations: BrowserNavigationOperations,
        javaScriptOperations: BrowserJavaScriptOperations,
        domOperations: BrowserDOMOperations,
        elementOperations: BrowserElementOperations,
        captureOperations: BrowserCaptureOperations
    ) {
        self.pool = pool
        self.sessionFactory = sessionFactory
        self.userAgentManager = userAgentManager
        self.eventEmitter = eventEmitter
        self.metrics = metrics
        self.logger = logger
        self.coordinator = coordinator
        self.navigationOperations = navigationOperations
        self.javaScriptOperations = javaScriptOperations
        self.domOperations = domOperations
        self.elementOperations = elementOperations
        self.captureOperations = captureOperations
    }

    @discardableResult
    func createSession(
        configuration: BrowserSessionConfiguration
    ) throws -> BrowserID {
        try pool.ensureCapacity()
        let startedAt = Date()
        let browserId = BrowserID()
        eventEmitter.emit(.stateChanged(browserId, .creating))
        let session = sessionFactory.makeSession(
            browserId: browserId,
            configuration: configuration
        )
        try pool.insert(session)

        let duration = Date().timeIntervalSince(startedAt)
        metrics.sessionCreated(
            browserId: browserId,
            createdAt: session.createdAt,
            creationDuration: duration
        )
        logger.log(
            .info,
            category: .browser,
            message: "Browser session created",
            metadata: [
                "browserId": browserId.description,
                "creationDuration": String(duration)
            ]
        )
        eventEmitter.emit(.created(browserId))
        return browserId
    }

    private func session(for browserId: BrowserID) throws -> BrowserSession {
        guard let session = pool.session(for: browserId) else {
            throw BrowserError.invalidSession(browserId)
        }
        return session
    }

    private func validatedSession(for browserId: BrowserID) throws -> BrowserSession {
        let session = try session(for: browserId)
        guard session.state != .destroyed, session.state != .stopping else {
            throw BrowserError.invalidOperationState(session.state)
        }
        return session
    }

    func load(_ request: BrowserRequest, in browserId: BrowserID) async throws {
        let session = try validatedSession(for: browserId)
        try await coordinator.run(browserId: browserId, name: "navigation.load", timeout: request.timeout) {
            try self.navigationOperations.load(request, in: session)
        }
    }

    func load(_ url: URL, in browserId: BrowserID, timeout: TimeInterval = 30) async throws {
        try await load(BrowserRequest(url: url, timeout: timeout), in: browserId)
    }

    func reload(_ browserId: BrowserID, fromOrigin: Bool = false) async throws {
        let session = try validatedSession(for: browserId)
        try await coordinator.run(browserId: browserId, name: "navigation.reload", timeout: 10) {
            self.navigationOperations.reload(session, fromOrigin: fromOrigin)
        }
    }

    func stopLoading(_ browserId: BrowserID) throws {
        navigationOperations.stop(try validatedSession(for: browserId))
    }

    func goBack(_ browserId: BrowserID) throws {
        navigationOperations.back(try validatedSession(for: browserId))
    }

    func goForward(_ browserId: BrowserID) throws {
        navigationOperations.forward(try validatedSession(for: browserId))
    }

    func evaluateJavaScript(
        _ source: String,
        in browserId: BrowserID,
        timeout: TimeInterval = 15
    ) async throws -> BrowserValue {
        let session = try validatedSession(for: browserId)
        return try await coordinator.run(browserId: browserId, name: "javascript.evaluate", timeout: timeout) {
            try await self.javaScriptOperations.evaluate(source, in: session)
        }
    }

    func elementExists(_ selector: String, in browserId: BrowserID, timeout: TimeInterval = 10) async throws -> Bool {
        let session = try validatedSession(for: browserId)
        return try await coordinator.run(browserId: browserId, name: "dom.exists", timeout: timeout) {
            try await self.domOperations.exists(selector: selector, in: session)
        }
    }

    func elementCount(_ selector: String, in browserId: BrowserID) async throws -> Int {
        let session = try validatedSession(for: browserId)
        return try await coordinator.run(browserId: browserId, name: "dom.count", timeout: 10) {
            try await self.domOperations.count(selector: selector, in: session)
        }
    }

    func elementProperty(_ property: String, selector: String, in browserId: BrowserID) async throws -> BrowserValue {
        let session = try validatedSession(for: browserId)
        return try await coordinator.run(browserId: browserId, name: "dom.property", timeout: 10) {
            try await self.domOperations.query(selector: selector, property: property, in: session)
        }
    }

    func perform(_ action: BrowserElementAction, selector: String, in browserId: BrowserID) async throws {
        let session = try validatedSession(for: browserId)
        try await coordinator.run(browserId: browserId, name: "element.interact", timeout: 10) {
            try await self.elementOperations.perform(action, selector: selector, in: session)
        }
    }

    func pageReadyState(in browserId: BrowserID) async throws -> String {
        let value = try await evaluateJavaScript("document.readyState", in: browserId)
        guard case .string(let state) = value else { throw BrowserError.serializationFailed("readyState") }
        return state
    }

    func pageHTML(in browserId: BrowserID) async throws -> String {
        let value = try await evaluateJavaScript("document.documentElement.outerHTML", in: browserId)
        guard case .string(let html) = value else { throw BrowserError.serializationFailed("page HTML") }
        return html
    }

    func documentText(in browserId: BrowserID) async throws -> String {
        let value = try await evaluateJavaScript("document.body?.innerText ?? ''", in: browserId)
        guard case .string(let text) = value else { throw BrowserError.serializationFailed("document text") }
        return text
    }

    func wait(for condition: NavigationCondition, in browserId: BrowserID, timeout: TimeInterval) async throws -> BrowserSnapshot {
        try await coordinator.run(browserId: browserId, name: "navigation.wait", timeout: timeout) {
            while true {
                try Task.checkCancellation()
                let snapshot = try self.snapshot(for: browserId)
                if try condition.matches(snapshot) { return snapshot }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func cookies(in browserId: BrowserID) async throws -> [BrowserCookie] {
        try await validatedSession(for: browserId).cookieManager.exportCookies()
    }

    func importCookies(_ cookies: [BrowserCookie], into browserId: BrowserID) async throws {
        try await validatedSession(for: browserId).cookieManager.importCookies(cookies)
    }

    func clearCookies(in browserId: BrowserID) async throws {
        let session = try validatedSession(for: browserId)
        await session.cookieManager.clear()
    }

    func inspectStorage(in browserId: BrowserID) async throws -> BrowserStorageSnapshot {
        let session = try validatedSession(for: browserId)
        return await session.storageManager.inspect()
    }

    func clearStorage(_ scope: BrowserStorageScope, in browserId: BrowserID) async throws {
        let session = try validatedSession(for: browserId)
        await session.storageManager.clear(scope)
    }

    func captureScreenshot(
        in browserId: BrowserID,
        format: BrowserScreenshotResult.Format = .png,
        quality: Double = 0.9,
        fullContent: Bool = false
    ) async throws -> BrowserScreenshotResult {
        let session = try validatedSession(for: browserId)
        return try await coordinator.run(browserId: browserId, name: "capture.screenshot", timeout: 30) {
            try await self.captureOperations.capture(
                session: session, format: format, quality: quality, fullContent: fullContent
            )
        }
    }

    func snapshot(for browserId: BrowserID) throws -> BrowserSnapshot {
        try session(for: browserId).snapshot
    }

    func allSnapshots() -> [BrowserSnapshot] {
        pool.browserIDs.compactMap { pool.session(for: $0)?.snapshot }
    }

    func presentationWebView(for browserId: BrowserID) throws -> WKWebView {
        try session(for: browserId).webView
    }

    func updateMetadata(_ metadata: BrowserMetadata, for browserId: BrowserID) throws {
        try session(for: browserId).updateMetadata(metadata)
    }

    func updateUserAgent(_ selection: UserAgentSelection, for browserId: BrowserID) throws {
        try session(for: browserId).updateUserAgent(userAgentManager.resolve(selection))
    }

    func updateViewport(
        size: CGSize,
        safeAreaInsets: UIEdgeInsets,
        scale: CGFloat,
        for browserId: BrowserID
    ) throws {
        let viewport = BrowserViewport(
            width: Double(size.width),
            height: Double(size.height),
            scale: Double(scale),
            safeAreaTop: Double(safeAreaInsets.top),
            safeAreaLeft: Double(safeAreaInsets.left),
            safeAreaBottom: Double(safeAreaInsets.bottom),
            safeAreaRight: Double(safeAreaInsets.right)
        )
        try session(for: browserId).updateViewport(viewport)
    }

    func destroySession(
        _ browserId: BrowserID,
        cleanupPolicy: BrowserCleanupPolicy = .discardSession
    ) async throws {
        guard let session = pool.remove(browserId: browserId) else {
            throw BrowserError.invalidSession(browserId)
        }
        coordinator.cancelAll(for: browserId)

        await session.shutdown(clearData: cleanupPolicy == .clearWebsiteData)
        metrics.sessionDestroyed(browserId: browserId)
        logger.log(
            .info,
            category: .browser,
            message: "Browser session destroyed",
            metadata: ["browserId": browserId.description]
        )
        eventEmitter.emit(.destroyed(browserId))
    }

    func destroyAllSessions(
        cleanupPolicy: BrowserCleanupPolicy = .discardSession
    ) async {
        let sessions = pool.removeAll()
        for session in sessions {
            await session.shutdown(clearData: cleanupPolicy == .clearWebsiteData)
            metrics.sessionDestroyed(browserId: session.browserId)
            logger.log(
                .info,
                category: .browser,
                message: "Browser session destroyed",
                metadata: ["browserId": session.browserId.description]
            )
            eventEmitter.emit(.destroyed(session.browserId))
        }
    }

    func metricsSnapshot() -> BrowserEngineMetrics {
        metrics.snapshot()
    }
}
