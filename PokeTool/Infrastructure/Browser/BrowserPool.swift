import Foundation

@MainActor
final class BrowserPool {
    private var sessions: [BrowserID: BrowserSession] = [:]

    var browserIDs: [BrowserID] {
        Array(sessions.keys)
    }

    func insert(_ session: BrowserSession) {
        precondition(sessions[session.browserId] == nil, "Duplicate browserId")
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
        sessions.removeAll()
        return removed
    }
}

