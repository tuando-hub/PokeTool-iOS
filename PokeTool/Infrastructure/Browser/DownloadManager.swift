import Foundation

struct BrowserDownloadID: Hashable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String {
        rawValue.uuidString
    }
}

enum BrowserDownloadState: Equatable {
    case pending
    case running(progress: Double)
    case finished(fileURL: URL)
    case failed(BrowserError)
    case cancelled
}

struct BrowserDownloadRecord: Equatable {
    let id: BrowserDownloadID
    let suggestedFilename: String?
    let startedAt: Date
    var state: BrowserDownloadState
}

struct BrowserDownloadSummary: Equatable {
    let active: Int
    let finished: Int
    let failed: Int

    static let empty = BrowserDownloadSummary(active: 0, finished: 0, failed: 0)
}

@MainActor
final class DownloadManager {
    private let browserId: BrowserID
    private let eventEmitter: BrowserEventEmitter
    private(set) var records: [BrowserDownloadID: BrowserDownloadRecord] = [:]

    init(browserId: BrowserID, eventEmitter: BrowserEventEmitter) {
        self.browserId = browserId
        self.eventEmitter = eventEmitter
    }

    var summary: BrowserDownloadSummary {
        var active = 0
        var finished = 0
        var failed = 0

        for record in records.values {
            switch record.state {
            case .pending, .running:
                active += 1
            case .finished:
                finished += 1
            case .failed:
                failed += 1
            case .cancelled:
                break
            }
        }
        return BrowserDownloadSummary(active: active, finished: finished, failed: failed)
    }

    // WKDownload delegate integration is intentionally deferred. These lifecycle
    // hooks keep download state ownership inside the Browser Engine.
    func register(suggestedFilename: String?) -> BrowserDownloadID {
        let id = BrowserDownloadID()
        records[id] = BrowserDownloadRecord(
            id: id,
            suggestedFilename: suggestedFilename,
            startedAt: Date(),
            state: .pending
        )
        eventEmitter.emit(.downloadStarted(browserId, id))
        return id
    }

    func update(_ id: BrowserDownloadID, state: BrowserDownloadState) {
        guard var record = records[id] else { return }
        record.state = state
        records[id] = record
        if case .finished = state {
            eventEmitter.emit(.downloadFinished(browserId, id))
        } else if case .failed(let error) = state {
            eventEmitter.emit(.downloadFailed(browserId, id, error))
        }
    }

    func cancelAll() {
        for id in Array(records.keys) {
            update(id, state: .cancelled)
        }
    }
}
