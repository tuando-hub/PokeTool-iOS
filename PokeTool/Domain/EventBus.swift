import Combine
import Foundation

struct PlatformEvent: Equatable {
    enum Source: String {
        case browser
        case runtime
        case bridge
        case network
        case storage
        case ui
        case plugin
        case system
    }

    let name: String
    let source: Source
    let timestamp: Date
    let correlationID: String?
    let attributes: [String: String]

    init(
        name: String,
        source: Source,
        timestamp: Date = Date(),
        correlationID: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.name = name
        self.source = source
        self.timestamp = timestamp
        self.correlationID = correlationID
        self.attributes = attributes
    }
}

protocol EventBus: AnyObject {
    var events: AnyPublisher<PlatformEvent, Never> { get }
    func publish(_ event: PlatformEvent)
}

