import Foundation

enum BrowserError: Error, Equatable, LocalizedError {
    case navigationFailed(code: Int, message: String)
    case timeout(operation: String)
    case cancelled(operation: String)
    case webProcessTerminated
    case processTerminated
    case invalidSession(BrowserID)
    case invalidURL(String)
    case invalidState(from: BrowserState, to: BrowserState)
    case invalidOperationState(BrowserState)
    case poolCapacityExceeded(maximum: Int)
    case cookieOperationFailed(String)
    case storageOperationFailed(String)
    case downloadFailed(String)
    case serializationFailed(String)
    case selectorSyntaxError(String)
    case elementNotFound(String)
    case elementNotVisible(String)
    case elementDisabled(String)
    case unsupportedOperation(String)
    case javaScriptExecutionFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .navigationFailed(_, let value): return "Navigation failed: \(value)"
        case .timeout(let value): return "Browser operation timed out: \(value)"
        case .cancelled(let value): return "Browser operation cancelled: \(value)"
        case .webProcessTerminated, .processTerminated: return "The WebKit content process terminated."
        case .invalidSession(let id): return "Browser session does not exist: \(id)"
        case .invalidURL(let value): return "Invalid URL: \(value)"
        case .invalidState(let from, let to): return "Invalid browser transition: \(from.rawValue) -> \(to.rawValue)"
        case .invalidOperationState(let state): return "Operation is not allowed while browser is \(state.rawValue)."
        case .poolCapacityExceeded(let maximum): return "Browser pool capacity exceeded: \(maximum)"
        case .cookieOperationFailed(let value): return "Cookie operation failed: \(value)"
        case .storageOperationFailed(let value): return "Storage operation failed: \(value)"
        case .downloadFailed(let value): return "Download failed: \(value)"
        case .serializationFailed(let value): return "Serialization failed: \(value)"
        case .selectorSyntaxError(let value): return "Invalid CSS selector: \(value)"
        case .elementNotFound(let value): return "Element not found: \(value)"
        case .elementNotVisible(let value): return "Element is not visible: \(value)"
        case .elementDisabled(let value): return "Element is disabled: \(value)"
        case .unsupportedOperation(let value): return "Unsupported browser operation: \(value)"
        case .javaScriptExecutionFailed(let value): return "JavaScript execution failed: \(value)"
        case .unknown(let value): return "Unknown browser error: \(value)"
        }
    }
}
