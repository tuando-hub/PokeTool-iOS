import Foundation

@MainActor
final class BrowserPool {
    private var sessions: [BrowserID: BrowserSession] = [:]
    private let maximumSessions: Int

    init(maximumSessions: Int) {
        precondition(maximumSessions > 0)
        self.maximumSessions = maximumSessions
    }

    var browserIDs: [BrowserID] {
        Array(sessions.keys)
    }

    var count: Int {
        sessions.count
    }

    func ensureCapacity() throws {
        guard sessions.count < maximumSessions else {
            throw BrowserError.poolCapacityExceeded(maximum: maximumSessions)
        }
    }

    func insert(_ session: BrowserSession) throws {
        try ensureCapacity()
        guard sessions[session.browserId] == nil else {
            throw BrowserError.unknown("Duplicate browserId \(session.browserId)")
        }
        sessions[session.browserId] = session
    }

    func session(for browserId: BrowserID) -> BrowserSession? {
        sessions[browserId]
    }

    @discardableResult
    func remove(browserId: BrowserID) -> BrowserSession? {
        sessions.removeValue(forKey: browserId)
    }

    func removeAll() -> [BrowserSession] {
        let removed = Array(sessions.values)
        sessions.removeAll(keepingCapacity: false)
        return removed
    }
}
