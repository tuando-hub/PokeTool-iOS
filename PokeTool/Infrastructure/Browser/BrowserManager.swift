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

    init(
        pool: BrowserPool,
        sessionFactory: BrowserSessionFactory,
        userAgentManager: UserAgentManager,
        eventEmitter: BrowserEventEmitter,
        metrics: BrowserMetricsCollector,
        logger: Logging
    ) {
        self.pool = pool
        self.sessionFactory = sessionFactory
        self.userAgentManager = userAgentManager
        self.eventEmitter = eventEmitter
        self.metrics = metrics
        self.logger = logger
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

    func session(for browserId: BrowserID) throws -> BrowserSession {
        guard let session = pool.session(for: browserId) else {
            throw BrowserError.invalidSession(browserId)
        }
        return session
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
