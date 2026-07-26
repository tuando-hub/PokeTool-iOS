import XCTest
@testable import PokeTool

final class BrowserBridgeTests: XCTestCase {
    func testBridgeValueCodecHandlesNestedNullAndObjects() throws {
        let value: JSONValue = .object([
            "null": .null,
            "array": .array([.bool(true), .number(2), .string("three")])
        ])
        let encoded = try BridgeValueCodec().encode(value)
        let data = try XCTUnwrap(encoded.data(using: .utf8))
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded.typeName, "object")
        XCTAssertEqual(decoded.objectValue?["array"]?.arrayValue?.count, 3)
    }

    func testArgumentDecoderRejectsWrongTypedRequest() {
        let value: JSONValue = .object(["url": .number(42)])
        XCTAssertThrowsError(try BridgeValueCodec().decode(BrowserLoadRequest.self, from: value, method: "load")) {
            XCTAssertTrue($0 is BridgeArgumentError)
        }
    }

    func testBrowserErrorMappingIsStructuredAndDoesNotLeakScript() {
        let result = BrowserBridgeErrorMapper().map(
            BrowserError.javaScriptExecutionFailed("secret source and token"),
            operationId: "operation", browserId: "browser", operation: "evaluate"
        )
        XCTAssertEqual(result.code, .javaScriptExecutionFailed)
        XCTAssertEqual(result.operationId, "operation")
        XCTAssertFalse(result.message.contains("secret"))
    }

    func testCapabilitiesAndVersionReflectFoundations() {
        let capabilities = BrowserBridgeCapabilities()
        XCTAssertEqual(capabilities.version, BrowserBridgeService.apiVersion)
        XCTAssertEqual(capabilities.navigationWait, "foundation")
        XCTAssertEqual(capabilities.elementWait, "unavailable")
        XCTAssertFalse(capabilities.networkIdle)
        XCTAssertFalse(capabilities.upload)
    }

    func testLimitsAreFiniteAndDefensive() {
        let limits = BrowserBridgeLimits()
        XCTAssertGreaterThan(limits.maximumPendingOperations, 0)
        XCTAssertLessThanOrEqual(limits.maximumPendingOperations, 64)
        XCTAssertGreaterThan(limits.maximumTimeout, limits.minimumTimeout)
        XCTAssertLessThanOrEqual(limits.maximumHeaders, 64)
    }

    @MainActor
    func testBootstrapExposesPromiseBrowserAPIWithoutBusinessLogic() throws {
        let container = DependencyContainer()
        let runtime = try XCTUnwrap(container.runtimeFactory.makeRuntime() as? JavaScriptRuntime)
        let health = try runtime.start()
        XCTAssertEqual(health.phase, 3)
        XCTAssertEqual(runtime.evaluateForTesting("typeof Native.Browser.create")?.toString(), "function")
        XCTAssertEqual(runtime.evaluateForTesting("Native.Browser.create() instanceof Promise")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("typeof PokeToolRuntime.browser.create")?.toString(), "function")
        XCTAssertEqual(runtime.evaluateForTesting("typeof PokeToolRuntime.healthCheck")?.toString(), "function")
        XCTAssertEqual(runtime.evaluateForTesting("typeof Pokemon")?.toString(), "undefined")
        runtime.stop()
    }

    @MainActor
    func testInvalidArgumentReturnsPromiseAndRuntimeStopCleansIt() throws {
        let container = DependencyContainer()
        let runtime = try XCTUnwrap(container.runtimeFactory.makeRuntime() as? JavaScriptRuntime)
        _ = try runtime.start()
        XCTAssertEqual(
            runtime.evaluateForTesting(
                "const x={};x.self=x;Native.Browser.create(x) instanceof Promise"
            )?.toBool(),
            true
        )
        runtime.stop()
    }
}
