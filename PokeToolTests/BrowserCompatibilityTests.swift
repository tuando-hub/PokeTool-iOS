import XCTest
@testable import PokeTool

final class BrowserCompatibilityTests: XCTestCase {
    @MainActor
    func testDelayResolvesAndPageCompatibilityOperations() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try await runtime.runAsyncTestScript(
            """
            const web = PokeToolRuntime.web;
            const started = Date.now();
            await web.delay(120);
            const delayElapsed = Date.now() - started;
            const browser = await PokeToolRuntime.browser.create();
            await browser.load("about:blank");
            await web.waitPageReady(browser, 3000);
            await web.evalJS(browser, `
              document.title = "Compat Test";
              document.body.innerHTML =
                '<div id="visible" style="display:block;width:120px;height:24px">Hello Compat</div>' +
                '<div id="hidden" style="display:none">Hidden</div>' +
                '<input id="email" value="">';
            `);
            const visible = await web.waitVisible(browser, "#visible", 1000);
            const exists = await web.waitExists(browser, "#email", 1000);
            await web.setValue(browser, "#email", "test@example.com");
            const value = await web.evalJS(browser, "document.querySelector('#email').value");
            const text = await web.waitText(browser, "Compat", 1000);
            await web.evalJS(browser, "document.querySelector('#visible').remove()");
            const gone = await web.waitGone(browser, "#visible", 1000);
            const urlString = await web.waitURL(browser, "about:", 1000);
            const urlRegex = await web.waitURL(browser, /^about:/, 1000);
            const title = await web.waitTitle(browser, /Compat Test/, 1000);
            let hiddenCode = null;
            try { await web.waitVisible(browser, "#hidden", 300); }
            catch (error) { hiddenCode = error.code; }
            let missingTapCode = null;
            try { await web.tapButton(browser, "#missing"); }
            catch (error) { missingTapCode = error.code; }
            const firstDestroy = await web.safeDestroy(browser);
            const secondDestroy = await web.safeDestroy(browser);
            return {
              delayElapsed, visible:Boolean(visible), exists, value, gone, text:Boolean(text),
              urlString, urlRegex, title, hiddenCode, missingTapCode,
              firstDestroy, secondDestroy
            };
            """
        )
        let value = try valueObject(result)
        XCTAssertGreaterThanOrEqual(value["delayElapsed"] as? Int ?? 0, 100)
        XCTAssertEqual(value["exists"] as? Bool, true)
        XCTAssertEqual(value["value"] as? String, "test@example.com")
        XCTAssertEqual(value["gone"] as? Bool, true)
        XCTAssertEqual(value["urlString"] as? String, "about:blank")
        XCTAssertEqual(value["urlRegex"] as? String, "about:blank")
        XCTAssertEqual(value["title"] as? String, "Compat Test")
        XCTAssertEqual(value["hiddenCode"] as? String, "ELEMENT_NOT_VISIBLE")
        XCTAssertEqual(value["missingTapCode"] as? String, "ELEMENT_NOT_FOUND")
        XCTAssertEqual((value["secondDestroy"] as? [String: Any])?["alreadyDestroyed"] as? Bool, true)
    }

    @MainActor
    func testWaitPageReadyTimeoutAndReloadOnceLimit() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try await runtime.runAsyncTestScript(
            """
            const web = PokeToolRuntime.web;
            let timeoutCode = null;
            try {
              await web.waitPageReady({readyState:async () => "loading"}, 300);
            } catch (error) { timeoutCode = error.code; }
            let reloadCount = 0;
            const fake = {
              readyState: async () => "complete",
              reload: async () => { reloadCount += 1; }
            };
            const recovery = await web.reloadOnce(fake, {
              timeout: 1000,
              check: async () => reloadCount === 1
            });
            return {timeoutCode, reloadCount, recovery};
            """
        )
        let value = try valueObject(result)
        XCTAssertEqual(value["timeoutCode"] as? String, "WAIT_TIMEOUT")
        XCTAssertEqual(value["reloadCount"] as? Int, 1)
        XCTAssertEqual((value["recovery"] as? [String: Any])?["reloaded"] as? Bool, true)
    }

    @MainActor
    func testDestroyDuringPollingSettlesWithoutRegistryLeak() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try await runtime.runAsyncTestScript(
            """
            const web = PokeToolRuntime.web;
            const browser = await PokeToolRuntime.browser.create();
            await browser.load("about:blank");
            const pending = web.waitExists(browser, "#never", 5000);
            await web.delay(100);
            await web.safeDestroy(browser);
            let code = null;
            try { await pending; } catch (error) { code = error.code; }
            return {code};
            """
        )
        let code = try valueObject(result)["code"] as? String
        XCTAssertTrue(
            code == "BROWSER_DESTROYED" || code == "OPERATION_CANCELLED",
            "Destroy must settle polling through session invalidation or operation cancellation."
        )
    }

    @MainActor
    func testRuntimeStopCancelsPendingCompatibilityDelay() throws {
        let runtime = try makeRuntime()
        XCTAssertEqual(
            runtime.evaluateForTesting("PokeToolRuntime.web.delay(10000) instanceof Promise")?.toBool(),
            true
        )
        runtime.stop()
        XCTAssertNil(runtime.evaluateForTesting("1"))
    }

    @MainActor
    func testNamespaceDoesNotLoadBusinessGlobals() throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        XCTAssertEqual(runtime.evaluateForTesting("typeof PokeToolRuntime.web")?.toString(), "object")
        XCTAssertEqual(runtime.evaluateForTesting("PokeToolRuntime.phase")?.toInt32(), 7)
        XCTAssertEqual(runtime.evaluateForTesting("typeof Pokemon")?.toString(), "undefined")
        XCTAssertEqual(runtime.evaluateForTesting("typeof OTP")?.toString(), "undefined")
    }

    @MainActor
    private func makeRuntime() throws -> JavaScriptRuntime {
        let container = DependencyContainer()
        let runtime = try XCTUnwrap(container.runtimeFactory.makeRuntime() as? JavaScriptRuntime)
        _ = try runtime.start()
        return runtime
    }

    private func valueObject(_ result: String) throws -> [String: Any] {
        let data = try XCTUnwrap(result.data(using: .utf8))
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(root["ok"] as? Bool, true, "Async JS failed: \(result)")
        return try XCTUnwrap(root["value"] as? [String: Any])
    }
}
