import XCTest
@testable import PokeTool

final class BrowserOperationTests: XCTestCase {
    func testBrowserValueConvertsNestedSerializableResult() throws {
        let value = try BrowserValue(any: ["ok": true, "items": [1, "two", NSNull()]])
        XCTAssertEqual(value, .object([
            "ok": .bool(true),
            "items": .array([.integer(1), .string("two"), .null])
        ]))
        XCTAssertNoThrow(try JSONEncoder().encode(value))
    }

    func testBrowserValueRejectsUnsupportedResult() {
        XCTAssertThrowsError(try BrowserValue(any: Date())) {
            XCTAssertEqual($0 as? BrowserError, .serializationFailed("Unsupported JavaScript result type"))
        }
    }

    func testRequestValidationRejectsSchemeAndHeaderInjection() {
        XCTAssertThrowsError(try BrowserRequest(url: URL(string: "javascript:alert(1)")!).validatedURLRequest())
        var request = BrowserRequest(url: URL(string: "https://example.com")!)
        request.headers = ["Authorization\nInjected": "secret"]
        XCTAssertThrowsError(try request.validatedURLRequest())
    }

    func testNavigationConditionAndRegexValidation() throws {
        let id = BrowserID()
        let navigation = BrowserNavigationSnapshot(
            currentURL: URL(string: "https://example.com/products/42"),
            previousURL: nil, title: "Products", estimatedProgress: 1,
            navigationType: .other, history: BrowserHistory()
        )
        let snapshot = BrowserSnapshot(
            browserId: id, state: .ready, loadingState: .idle,
            navigationState: .completed, navigation: navigation,
            metadata: .presentation, userAgent: nil, viewport: .zero,
            downloadState: .empty, storageState: .clean, createdAt: Date()
        )
        XCTAssertTrue(try NavigationCondition.urlRegex(#"/products/\d+$"#).matches(snapshot))
        XCTAssertThrowsError(try NavigationCondition.urlRegex("[").matches(snapshot))
    }

    func testRedactorRemovesSensitiveValuesOnly() {
        let result = BrowserRedactor().redact([
            "Authorization": "Bearer secret", "password": "secret", "requestId": "123"
        ])
        XCTAssertEqual(result["Authorization"], "<redacted>")
        XCTAssertEqual(result["password"], "<redacted>")
        XCTAssertEqual(result["requestId"], "123")
    }

    func testScreenshotAndDownloadDestinationsAreUniqueAndControlled() throws {
        let screenshots = ControlledScreenshotDestinationPolicy()
        let first = try screenshots.destination(format: .png)
        let second = try screenshots.destination(format: .png)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first.pathExtension, "png")

        let downloads = ControlledDownloadDestinationPolicy()
        let destination = try downloads.destination(suggestedFilename: "../../secret.txt")
        XCTAssertTrue(destination.lastPathComponent.hasSuffix("-secret.txt"))
        XCTAssertFalse(destination.lastPathComponent.contains(".."))
    }

    @MainActor
    func testOperationMetricsTrackOutcome() {
        let metrics = BrowserMetricsCollector()
        metrics.operationStarted()
        metrics.operationFinished(duration: 0.5, succeeded: false)
        metrics.operationStarted()
        metrics.operationCancelled()
        let snapshot = metrics.snapshot()
        XCTAssertEqual(snapshot.operationCount, 2)
        XCTAssertEqual(snapshot.activeOperationCount, 0)
        XCTAssertEqual(snapshot.failedOperationCount, 1)
        XCTAssertEqual(snapshot.cancelledOperationCount, 1)
    }
}
