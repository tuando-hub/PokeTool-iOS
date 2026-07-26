import XCTest
@testable import PokeTool

final class JavaScriptModuleSystemTests: XCTestCase {
    private let limits = JavaScriptModuleLimits()

    func testResolverCanonicalizesRelativeExtensionAndParentPaths() throws {
        let resolver = JavaScriptModuleResolver(limits: limits)
        XCTAssertEqual(
            try resolver.resolve("./child", from: "/modules/parent.js"),
            "/modules/child.js"
        )
        XCTAssertEqual(
            try resolver.resolve("./child.js", from: "/modules/parent.js"),
            "/modules/child.js"
        )
        XCTAssertEqual(
            try resolver.resolve("../shared/value", from: "/modules/nested/parent.js"),
            "/modules/shared/value.js"
        )
        XCTAssertEqual(
            try resolver.resolve("/runtime/helpers", from: "/modules/parent.js"),
            "/runtime/helpers.js"
        )
    }

    func testResolverRejectsTraversalAndUnsupportedIdentifiers() {
        let resolver = JavaScriptModuleResolver(limits: limits)
        XCTAssertThrowsError(try resolver.resolve("../../secret", from: "/module.js")) {
            XCTAssertEqual(($0 as? JavaScriptModuleError)?.code, .pathOutsideRoot)
        }
        for value in ["", "https://example.com/a.js", #"C:\secret.js"#, "file:///tmp/a.js", "bad\0id"] {
            XCTAssertThrowsError(try resolver.resolve(value, from: "/module.js"))
        }
    }

    func testInMemorySourceProviderReturnsMetadataAndEnforcesSize() throws {
        let provider = InMemoryJavaScriptModuleSourceProvider(
            sources: ["/a.js": "exports.value = 1;"], limits: limits
        )
        let source = try provider.source(for: "/a.js")
        XCTAssertEqual(source.filename, "/a.js")
        XCTAssertEqual(source.directory, "/")
        XCTAssertEqual(source.origin, "memory")
        XCTAssertGreaterThan(source.byteCount, 0)
        XCTAssertThrowsError(try provider.source(for: "/missing.js")) {
            XCTAssertEqual(($0 as? JavaScriptModuleError)?.code, .moduleNotFound)
        }
    }

    @MainActor
    func testCommonJSSemanticsCacheCircularGraphAndFailureCleanup() throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try evaluateObject(
            runtime,
            """
            (function () {
              const simple = require("/modules/fixtures/simple-export");
              const named = require("/modules/fixtures/named-exports");
              const replacement = require("/modules/fixtures/replace-module-exports");
              const relative = require("/modules/fixtures/relative-parent");
              const nested = require("/modules/fixtures/nested/dependency");
              const first = require("/modules/fixtures/cache-counter");
              const second = require("/modules/fixtures/cache-counter.js");
              const circular = require("/modules/fixtures/circular-a");
              const metadata = require("/modules/fixtures/module-metadata");
              let failureCode = null;
              try { require("/modules/fixtures/throw-on-load"); }
              catch (error) { failureCode = error.code; }
              let missingCode = null;
              try { require("/modules/fixtures/missing"); }
              catch (error) { missingCode = error.code; }
              let traversalCode = null;
              try { require("../../outside"); }
              catch (error) { traversalCode = error.code; }
              const diagnostics = PokeToolRuntime.modules.graph();
              return {
                simple: simple.value, filename: simple.filename, dirname: simple.dirname,
                named: named.answer, replacement: replacement.value,
                relative: relative.dependency.child, nested: nested.child,
                cacheIdentity: first === second, executions: second.executions,
                circularA: circular.name, circularB: circular.fromB,
                loadedDuringExecution: metadata.loadedDuringExecution,
                metadataParent: metadata.parent, metadataID: metadata.id,
                metadataChild: metadata.children[0],
                failureCode: failureCode,
                missingCode: missingCode, traversalCode: traversalCode,
                failureCached: PokeToolRuntime.modules.isLoaded("/modules/fixtures/throw-on-load"),
                cacheCount: diagnostics.cacheCount,
                circularCount: diagnostics.circularDependencies.length
              };
            })()
            """
        )
        XCTAssertEqual(result["simple"] as? Int, 42)
        XCTAssertEqual(result["filename"] as? String, "/modules/fixtures/simple-export.js")
        XCTAssertEqual(result["dirname"] as? String, "/modules/fixtures")
        XCTAssertEqual(result["named"] as? Int, 42)
        XCTAssertEqual(result["replacement"] as? String, "replacement")
        XCTAssertEqual(result["relative"] as? Bool, true)
        XCTAssertEqual(result["nested"] as? Bool, true)
        XCTAssertEqual(result["cacheIdentity"] as? Bool, true)
        XCTAssertEqual(result["executions"] as? Int, 1)
        XCTAssertEqual(result["circularA"] as? String, "a")
        XCTAssertEqual(result["circularB"] as? String, "b")
        XCTAssertEqual(result["loadedDuringExecution"] as? Bool, false)
        XCTAssertTrue(result["metadataParent"] is NSNull)
        XCTAssertEqual(result["metadataID"] as? String, "/modules/fixtures/module-metadata.js")
        XCTAssertEqual(result["metadataChild"] as? String, "/modules/fixtures/relative-child.js")
        XCTAssertEqual(result["failureCode"] as? String, "MODULE_EXECUTION_FAILED")
        XCTAssertEqual(result["missingCode"] as? String, "MODULE_NOT_FOUND")
        XCTAssertEqual(result["traversalCode"] as? String, "MODULE_PATH_OUTSIDE_ROOT")
        XCTAssertEqual(result["failureCached"] as? Bool, false)
        XCTAssertGreaterThan(result["cacheCount"] as? Int ?? 0, 5)
        XCTAssertGreaterThan(result["circularCount"] as? Int ?? 0, 0)
    }

    @MainActor
    func testGlobalsCapabilitiesConsoleAndPhaseFourCompatibility() throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        XCTAssertEqual(runtime.evaluateForTesting("global.global === global")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("global.PokeToolRuntime === PokeToolRuntime")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("global.Native === Native")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("PokeToolRuntime.modules.version")?.toString(), "1.0.0")
        XCTAssertEqual(runtime.evaluateForTesting("PokeToolRuntime.modules.capabilities().commonJS")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("PokeToolRuntime.modules.capabilities().npm")?.toBool(), false)
        XCTAssertEqual(runtime.evaluateForTesting("require('/modules/fixtures/console-module')()")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("require('/compat/browser-compat') === PokeToolRuntime.web")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("typeof PokeToolRuntime.web.waitVisible")?.toString(), "function")
        XCTAssertEqual(runtime.evaluateForTesting("PokeToolRuntime.healthCheck().ok")?.toBool(), true)
        for name in ["Core", "Runner", "OTP", "Pokemon", "Jump"] {
            XCTAssertEqual(runtime.evaluateForTesting("typeof \(name)")?.toString(), "undefined")
        }
        XCTAssertEqual(
            runtime.evaluateForTesting(
                """
                (function () {
                  const first = require("/modules/fixtures/cache-counter");
                  PokeToolRuntime.modules.clear("/modules/fixtures/cache-counter");
                  const second = require("/modules/fixtures/cache-counter");
                  return second.executions === first.executions + 1;
                })()
                """
            )?.toBool(),
            true
        )
    }

    @MainActor
    func testTimersExecuteClearAndStopCleanup() async throws {
        let runtime = try makeRuntime()
        let result = try await runtime.runAsyncTestScript(
            """
            let fired = 0;
            const cancelled = setTimeout(() => { fired += 100; }, 40);
            clearTimeout(cancelled);
            await new Promise(resolve => setTimeout(() => { fired += 1; resolve(); }, 50));
            let intervalCount = 0;
            await new Promise(resolve => {
              const id = setInterval(() => {
                intervalCount += 1;
                if (intervalCount === 2) { clearInterval(id); resolve(); }
              }, 20);
            });
            return {fired, intervalCount, active: Native.Runtime.activeTimerCount()};
            """,
            timeout: 5
        )
        let object = try decodeAsyncValue(result)
        XCTAssertEqual(object["fired"] as? Int, 1)
        XCTAssertEqual(object["intervalCount"] as? Int, 2)
        runtime.stop()
        XCTAssertEqual(runtime.activeTimerCountForTesting, 0)
        XCTAssertNil(runtime.evaluateForTesting("require('/modules/fixtures/simple-export')"))
    }

    @MainActor
    private func makeRuntime() throws -> JavaScriptRuntime {
        let runtime = try XCTUnwrap(
            DependencyContainer().runtimeFactory.makeRuntime() as? JavaScriptRuntime
        )
        let health = try runtime.start()
        XCTAssertEqual(health.phase, 6)
        return runtime
    }

    @MainActor
    private func evaluateObject(_ runtime: JavaScriptRuntime, _ script: String) throws -> [String: Any] {
        let value = try XCTUnwrap(runtime.evaluateForTesting(script))
        return try XCTUnwrap(value.toDictionary() as? [String: Any])
    }

    private func decodeAsyncValue(_ result: String) throws -> [String: Any] {
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        XCTAssertEqual(root["ok"] as? Bool, true, result)
        return try XCTUnwrap(root["value"] as? [String: Any])
    }
}
