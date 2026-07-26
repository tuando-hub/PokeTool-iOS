import Foundation

enum BrowserError: Error, Equatable, LocalizedError {
    case navigationFailed(code: Int, message: String)
    case timeout(operation: String)
    case webProcessTerminated
    case invalidSession(BrowserID)
    case invalidURL(String)
    case invalidState(from: BrowserState, to: BrowserState)
    case poolCapacityExceeded(maximum: Int)
    case cookieOperationFailed(String)
    case storageOperationFailed(String)
    case downloadFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .navigationFailed(_, let message): return "Navigation failed: \(message)"
        case .timeout(let operation): return "Browser operation timed out: \(operation)"
        case .webProcessTerminated: return "The WebKit content process terminated."
        case .invalidSession(let id): return "Browser session does not exist: \(id)"
        case .invalidURL(let value): return "Invalid URL: \(value)"
        case .invalidState(let from, let to): return "Invalid browser transition: \(from.rawValue) → \(to.rawValue)"
        case .poolCapacityExceeded(let maximum): return "Browser pool capacity exceeded: \(maximum)"
        case .cookieOperationFailed(let message): return "Cookie operation failed: \(message)"
        case .storageOperationFailed(let message): return "Storage operation failed: \(message)"
        case .downloadFailed(let message): return "Download failed: \(message)"
        case .unknown(let message): return "Unknown browser error: \(message)"
        }
    }
}

