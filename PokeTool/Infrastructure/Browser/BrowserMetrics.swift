import Foundation
import os

struct BrowserSessionMetrics: Equatable {
    let browserId: BrowserID
    let createdAt: Date
    var creationDuration: TimeInterval
    var lastLoadDuration: TimeInterval?
    var totalLoadDuration: TimeInterval
    var navigationCount: Int
    var webProcessTerminationCount: Int
}

struct BrowserEngineMetrics: Equatable {
    let activeSessions: Int
    let totalSessionsCreated: Int
    let availableMemoryBytes: UInt64
    let sessions: [BrowserSessionMetrics]
}

@MainActor
final class BrowserMetricsCollector {
    private var sessions: [BrowserID: BrowserSessionMetrics] = [:]
    private(set) var totalSessionsCreated = 0

    func sessionCreated(
        browserId: BrowserID,
        createdAt: Date,
        creationDuration: TimeInterval
    ) {
        totalSessionsCreated += 1
        sessions[browserId] = BrowserSessionMetrics(
            browserId: browserId,
            createdAt: createdAt,
            creationDuration: creationDuration,
            lastLoadDuration: nil,
            totalLoadDuration: 0,
            navigationCount: 0,
            webProcessTerminationCount: 0
        )
    }

    func navigationFinished(browserId: BrowserID, duration: TimeInterval) {
        guard var metrics = sessions[browserId] else { return }
        metrics.navigationCount += 1
        metrics.lastLoadDuration = duration
        metrics.totalLoadDuration += duration
        sessions[browserId] = metrics
    }

    func webProcessTerminated(browserId: BrowserID) {
        guard var metrics = sessions[browserId] else { return }
        metrics.webProcessTerminationCount += 1
        sessions[browserId] = metrics
    }

    func sessionDestroyed(browserId: BrowserID) {
        sessions.removeValue(forKey: browserId)
    }

    func snapshot() -> BrowserEngineMetrics {
        BrowserEngineMetrics(
            activeSessions: sessions.count,
            totalSessionsCreated: totalSessionsCreated,
            availableMemoryBytes: UInt64(os_proc_available_memory()),
            sessions: sessions.values.sorted { $0.createdAt < $1.createdAt }
        )
    }
}
