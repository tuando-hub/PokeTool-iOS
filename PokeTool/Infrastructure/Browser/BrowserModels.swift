import Foundation

struct BrowserID: Hashable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String {
        rawValue.uuidString
    }
}

enum BrowserLoadingState: Equatable {
    case idle
    case loading
    case finished
    case failed(message: String)
}

enum BrowserNavigationState: Equatable {
    case initial
    case provisional
    case committed
    case completed
    case failed(message: String)
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

struct BrowserSnapshot: Equatable {
    let browserId: BrowserID
    let loadingState: BrowserLoadingState
    let navigationState: BrowserNavigationState
    let metadata: BrowserMetadata
    let userAgent: String?
}

