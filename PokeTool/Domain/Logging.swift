import Foundation

enum LogLevel: String {
    case debug
    case info
    case warning
    case error
    case critical
}

enum LogCategory: String {
    case browser
    case runtime
    case bridge
    case network
    case storage
    case ui
    case plugin
    case system
}

protocol Logging: AnyObject {
    func log(
        _ level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String]
    )
}

extension Logging {
    func log(
        _ level: LogLevel,
        category: LogCategory,
        message: String
    ) {
        log(level, category: category, message: message, metadata: [:])
    }
}

