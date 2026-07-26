import Foundation

enum BridgeErrorCode: String, Codable {
    case invalidArgument = "INVALID_ARGUMENT"
    case invalidSession = "INVALID_SESSION"
    case invalidState = "INVALID_STATE"
    case invalidURL = "INVALID_URL"
    case timeout = "TIMEOUT"
    case cancelled = "CANCELLED"
    case processTerminated = "PROCESS_TERMINATED"
    case serializationFailed = "SERIALIZATION_FAILED"
    case javaScriptExecutionFailed = "JAVASCRIPT_EXECUTION_FAILED"
    case selectorInvalid = "SELECTOR_INVALID"
    case elementNotFound = "ELEMENT_NOT_FOUND"
    case elementNotVisible = "ELEMENT_NOT_VISIBLE"
    case elementDisabled = "ELEMENT_DISABLED"
    case unsupportedOperation = "UNSUPPORTED_OPERATION"
    case cookieFailure = "COOKIE_FAILURE"
    case storageFailure = "STORAGE_FAILURE"
    case screenshotFailure = "SCREENSHOT_FAILURE"
    case downloadFailure = "DOWNLOAD_FAILURE"
    case internalError = "INTERNAL_ERROR"
}

struct StructuredBridgeError: Codable {
    let name: String
    let code: BridgeErrorCode
    let message: String
    let operationId: String
    let browserId: String?
    let operation: String
    let retryable: Bool
    let details: [String: JSONValue]
}

struct BrowserBridgeLimits {
    let maximumPendingOperations = 64
    let maximumSourceLength = 1_000_000
    let maximumHTMLResultLength = 5_000_000
    let maximumPayloadBytes = 2_000_000
    let maximumHeaders = 64
    let maximumMetadataEntries = 32
    let minimumTimeout: TimeInterval = 0.1
    let maximumTimeout: TimeInterval = 120
}

struct BrowserBridgeCapabilities: Codable, Equatable {
    let version = "1.0.0"
    let navigation = true
    let evaluate = true
    let domQuery = true
    let elementInteraction = true
    let navigationWait = "foundation"
    let elementWait = "unavailable"
    let networkIdle = false
    let screenshotViewport = true
    let screenshotFullContent = "limited"
    let cookies = true
    let cookieMutation = false
    let websiteData = true
    let download = "foundation"
    let upload = false
    let pageStorageKeys = false
    let recoveryReloadOnce = false
    let eventDelivery = "unavailable"
}

struct BrowserCreateOptions: Decodable {
    let persistence: String?
    let userAgent: String?
    let metadata: [String: String]?
}

struct BrowserTimeoutOptions: Decodable {
    let timeoutMs: Double?
    let correlationId: String?
}

struct BrowserLoadInput: Decodable {
    let browserId: String
    let request: BrowserLoadRequest
}

struct BrowserLoadRequest: Decodable {
    let url: String
    let method: String?
    let headers: [String: String]?
    let body: String?
    let cachePolicy: String?
    let timeoutMs: Double?
}

struct BrowserScreenshotOptions: Decodable {
    let format: String?
    let capture: String?
    let quality: Double?
}

struct BrowserNavigationConditionInput: Decodable {
    let type: String
    let value: String?
}

struct BrowserCookieFilter: Decodable {
    let url: String?
    let domain: String?
    let name: String?
}

struct BrowserBridgeErrorMapper {
    func map(
        _ error: Error,
        operationId: String,
        browserId: String?,
        operation: String
    ) -> StructuredBridgeError {
        let browserError = error as? BrowserError
        let code: BridgeErrorCode
        switch browserError {
        case .invalidSession: code = .invalidSession
        case .invalidState, .invalidOperationState: code = .invalidState
        case .invalidURL: code = .invalidURL
        case .timeout: code = .timeout
        case .cancelled: code = .cancelled
        case .processTerminated, .webProcessTerminated: code = .processTerminated
        case .serializationFailed: code = .serializationFailed
        case .javaScriptExecutionFailed: code = .javaScriptExecutionFailed
        case .selectorSyntaxError: code = .selectorInvalid
        case .elementNotFound: code = .elementNotFound
        case .elementNotVisible: code = .elementNotVisible
        case .elementDisabled: code = .elementDisabled
        case .unsupportedOperation: code = .unsupportedOperation
        case .cookieOperationFailed: code = .cookieFailure
        case .storageOperationFailed: code = .storageFailure
        case .downloadFailed: code = .downloadFailure
        default: code = error is BridgeArgumentError ? .invalidArgument : .internalError
        }
        return StructuredBridgeError(
            name: browserError == nil ? "BridgeError" : "BrowserError",
            code: code,
            message: safeMessage(error, code: code),
            operationId: operationId,
            browserId: browserId,
            operation: operation,
            retryable: code == .timeout || code == .processTerminated,
            details: [:]
        )
    }

    private func safeMessage(_ error: Error, code: BridgeErrorCode) -> String {
        if code == .javaScriptExecutionFailed { return "Page JavaScript execution failed." }
        return error.localizedDescription.prefix(500).description
    }
}

struct BridgeArgumentError: LocalizedError, Equatable {
    let method: String
    let argument: String
    let expected: String
    let received: String
    var errorDescription: String? {
        "\(method): argument '\(argument)' expected \(expected), received \(received)"
    }
}
