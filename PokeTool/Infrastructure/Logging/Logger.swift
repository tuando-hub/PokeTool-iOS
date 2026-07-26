import Foundation
import os

final class Logger {
    static let shared = Logger()
    private let logger = os.Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.dodinh.poketool",
        category: "PokeTool"
    )

    func write(level: String, message: String) {
        logger.info("[\(level, privacy: .public)] \(message, privacy: .private)")
    }
}

