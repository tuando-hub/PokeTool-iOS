import Foundation

struct BrowserID: Hashable, Codable, CustomStringConvertible, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String {
        rawValue.uuidString
    }
}

enum BrowserState: String, Codable {
    case idle
    case creating
    case loading
    case interactive
    case ready
    case busy
    case stopping
    case destroyed
}

enum BrowserLoadingState: Equatable {
    case idle
    case loading(startedAt: Date)
    case finished(duration: TimeInterval)
    case failed(BrowserError)
}

enum BrowserNavigationState: Equatable {
    case initial
    case provisional
    case committed
    case completed
    case failed(BrowserError)
    case processTerminated
}

enum BrowserNavigationType: String, Codable {
    case linkActivated
    case formSubmitted
    case backForward
    case reload
    case formResubmitted
    case other
    case unknown
}

struct BrowserHistoryEntry: Equatable, Codable {
    let url: URL
    let title: String?
    let visitedAt: Date
    let navigationType: BrowserNavigationType
}

struct BrowserHistory: Equatable, Codable {
    private(set) var entries: [BrowserHistoryEntry] = []
    private(set) var currentIndex: Int?

    var current: BrowserHistoryEntry? {
        guard let currentIndex, entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex]
    }

    mutating func append(_ entry: BrowserHistoryEntry) {
        if let currentIndex, currentIndex < entries.count - 1 {
            entries.removeSubrange((currentIndex + 1)...)
        }
        entries.append(entry)
        currentIndex = entries.count - 1
    }

    mutating func removeAll() {
        entries.removeAll()
        currentIndex = nil
    }
}

struct BrowserNavigationSnapshot: Equatable {
    let currentURL: URL?
    let previousURL: URL?
    let title: String?
    let estimatedProgress: Double
    let navigationType: BrowserNavigationType
    let history: BrowserHistory
}

struct BrowserViewport: Equatable, Codable {
    var width: Double
    var height: Double
    var scale: Double
    var safeAreaTop: Double
    var safeAreaLeft: Double
    var safeAreaBottom: Double
    var safeAreaRight: Double

    static let zero = BrowserViewport(
        width: 0,
        height: 0,
        scale: 1,
        safeAreaTop: 0,
        safeAreaLeft: 0,
        safeAreaBottom: 0,
        safeAreaRight: 0
    )
}

struct BrowserMetadata: Equatable {
    enum Purpose: String {
        case presentation
        case runtime
        case plugin
        case unspecified
    }

    var purpose: Purpose
    var label: String?
    var ownerID: String?
    var attributes: [String: String]

    static let presentation = BrowserMetadata(
        purpose: .presentation,
        label: "Browser",
        ownerID: nil,
        attributes: [:]
    )
}

enum BrowserDataStorePolicy {
    case isolated
    case shared
}

struct BrowserSessionConfiguration {
    var metadata: BrowserMetadata
    var userAgent: UserAgentSelection
    var dataStorePolicy: BrowserDataStorePolicy
    var viewport: BrowserViewport

    static let presentation = BrowserSessionConfiguration(
        metadata: .presentation,
        userAgent: .systemDefault,
        dataStorePolicy: .isolated,
        viewport: .zero
    )
}

struct BrowserEngineConfiguration {
    let maximumConcurrentSessions: Int

    static let `default` = BrowserEngineConfiguration(maximumConcurrentSessions: 8)
}

struct BrowserSnapshot: Equatable {
    let browserId: BrowserID
    let state: BrowserState
    let loadingState: BrowserLoadingState
    let navigationState: BrowserNavigationState
    let navigation: BrowserNavigationSnapshot
    let metadata: BrowserMetadata
    let userAgent: String?
    let viewport: BrowserViewport
    let downloadState: BrowserDownloadSummary
    let storageState: BrowserStorageState
    let createdAt: Date
}
