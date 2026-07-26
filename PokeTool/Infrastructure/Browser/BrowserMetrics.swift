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
    let operationCount: Int
    let activeOperationCount: Int
    let failedOperationCount: Int
    let cancelledOperationCount: Int
    let totalOperationDuration: TimeInterval
}

@MainActor
final class BrowserMetricsCollector {
    private var sessions: [BrowserID: BrowserSessionMetrics] = [:]
    private(set) var totalSessionsCreated = 0
    private(set) var operationCount = 0
    private(set) var activeOperationCount = 0
    private(set) var failedOperationCount = 0
    private(set) var cancelledOperationCount = 0
    private(set) var totalOperationDuration: TimeInterval = 0

    func operationStarted() {
        operationCount += 1
        activeOperationCount += 1
    }

    func operationFinished(duration: TimeInterval, succeeded: Bool) {
        activeOperationCount = max(0, activeOperationCount - 1)
        totalOperationDuration += duration
        if !succeeded { failedOperationCount += 1 }
    }

    func operationCancelled() {
        activeOperationCount = max(0, activeOperationCount - 1)
        cancelledOperationCount += 1
    }

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
            sessions: sessions.values.sorted { $0.createdAt < $1.createdAt },
            operationCount: operationCount,
            activeOperationCount: activeOperationCount,
            failedOperationCount: failedOperationCount,
            cancelledOperationCount: cancelledOperationCount,
            totalOperationDuration: totalOperationDuration
        )
    }
}
