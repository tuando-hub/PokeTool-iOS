import Foundation

struct BrowserOperationID: Hashable, Codable, Sendable {
    let rawValue: UUID
    init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

enum BrowserOperationState: String, Codable, Sendable {
    case created, validated, running, completed, failed, timedOut, cancelled, cleanedUp
}

struct BrowserOperationContext: Codable, Sendable {
    let id: BrowserOperationID
    let browserId: BrowserID
    let name: String
    let correlationID: String?
    let startedAt: Date
    let timeout: TimeInterval
    var state: BrowserOperationState
}

indirect enum BrowserValue: Equatable, Codable, Sendable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([BrowserValue])
    case object([String: BrowserValue])

    init(any value: Any?) throws {
        guard let value, !(value is NSNull) else { self = .null; return }
        switch value {
        case let value as Bool: self = .bool(value)
        case let value as String: self = .string(value)
        case let values as [Any]: self = .array(try values.map(BrowserValue.init(any:)))
        case let values as [String: Any]: self = .object(try values.mapValues(BrowserValue.init(any:)))
        case let value as NSNumber:
            let number = value.doubleValue
            guard number.isFinite else { throw BrowserError.serializationFailed("Non-finite number") }
            self = number.rounded() == number ? .integer(value.int64Value) : .number(number)
        default: throw BrowserError.serializationFailed("Unsupported JavaScript result type")
        }
    }
}

enum BrowserHTTPMethod: String, Codable, Sendable {
    case get = "GET", head = "HEAD", post = "POST", put = "PUT"
    case patch = "PATCH", delete = "DELETE", options = "OPTIONS"
}

struct BrowserRequest: Sendable {
    let url: URL
    var method: BrowserHTTPMethod = .get
    var headers: [String: String] = [:]
    var body: Data?
    var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    var timeout: TimeInterval = 30

    func validatedURLRequest(maximumBodyBytes: Int = 10 * 1_024 * 1_024) throws -> URLRequest {
        guard ["http", "https", "about", "file"].contains(url.scheme?.lowercased() ?? "") else {
            throw BrowserError.invalidURL(url.absoluteString)
        }
        guard timeout > 0, body?.count ?? 0 <= maximumBodyBytes else {
            throw BrowserError.unsupportedOperation("Invalid timeout or request body too large")
        }
        guard (headers.keys + headers.values).allSatisfy({ !$0.contains("\n") && !$0.contains("\r") }) else {
            throw BrowserError.serializationFailed("Invalid HTTP header")
        }
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        return request
    }
}

enum NavigationCondition: Sendable {
    case started, committed, finished, failed
    case urlEquals(String), urlContains(String), urlPrefix(String), urlSuffix(String), urlRegex(String)
    case titleEquals(String), titleContains(String), titleRegex(String)

    func matches(_ snapshot: BrowserSnapshot) throws -> Bool {
        let url = snapshot.navigation.currentURL?.absoluteString ?? ""
        let title = snapshot.navigation.title ?? ""
        switch self {
        case .started: return snapshot.navigationState == .provisional
        case .committed: return snapshot.navigationState == .committed
        case .finished: return snapshot.navigationState == .completed
        case .failed: if case .failed = snapshot.navigationState { return true }; return false
        case .urlEquals(let value): return url == value
        case .urlContains(let value): return url.contains(value)
        case .urlPrefix(let value): return url.hasPrefix(value)
        case .urlSuffix(let value): return url.hasSuffix(value)
        case .titleEquals(let value): return title == value
        case .titleContains(let value): return title.contains(value)
        case .urlRegex(let value): return try Self.regex(value, url)
        case .titleRegex(let value): return try Self.regex(value, title)
        }
    }

    private static func regex(_ pattern: String, _ value: String) throws -> Bool {
        do {
            let expression = try NSRegularExpression(pattern: pattern)
            return expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
        } catch { throw BrowserError.serializationFailed("Invalid regular expression") }
    }
}

struct BrowserVisibilitySnapshot: Codable, Equatable, Sendable {
    let visible: Bool
    let width: Double
    let height: Double
    let opacity: Double
}

struct BrowserScreenshotResult: Codable, Equatable, Sendable {
    enum Format: String, Codable, Sendable { case png, jpeg }
    let browserId: BrowserID
    let fileURL: URL
    let format: Format
    let width: Int
    let height: Int
    let timestamp: Date
}
