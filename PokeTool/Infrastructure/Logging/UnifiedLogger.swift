import Foundation
import os

final class UnifiedLogger: Logging {
    private let subsystem: String

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.dodinh.poketool") {
        self.subsystem = subsystem
    }

    func log(
        _ level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String]
    ) {
        let logger = os.Logger(subsystem: subsystem, category: category.rawValue)
        let suffix = metadata.isEmpty
            ? ""
            : " " + metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        let output = message + suffix

        switch level {
        case .debug:
            logger.debug("\(output, privacy: .private)")
        case .info:
            logger.info("\(output, privacy: .private)")
        case .warning:
            logger.warning("\(output, privacy: .private)")
        case .error:
            logger.error("\(output, privacy: .private)")
        case .critical:
            logger.critical("\(output, privacy: .private)")
        }
    }
}

