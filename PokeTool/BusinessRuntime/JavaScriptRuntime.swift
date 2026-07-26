import Foundation
import JavaScriptCore

enum JavaScriptRuntimeError: LocalizedError {
    case missingBootstrap
    case missingModuleLoader
    case evaluationFailed(String)
    case invalidHealthResponse

    var errorDescription: String? {
        switch self {
        case .missingBootstrap: return "JavaScript bootstrap resource is missing."
        case .missingModuleLoader: return "JavaScript module loader resource is missing."
        case .evaluationFailed(let message): return "JavaScript evaluation failed: \(message)"
        case .invalidHealthResponse: return "JavaScript runtime returned an invalid health response."
        }
    }
}

@MainActor
final class JavaScriptRuntime: BusinessRuntime {
    private let bridge: NativeBridge
    private let logger: Logging
    private var context: JSContext?

    init(bridge: NativeBridge, logger: Logging) {
        self.bridge = bridge
        self.logger = logger
    }

    func start() throws -> RuntimeHealth {
        stop()
        bridge.prepareForStart()

        guard let context = JSContext() else {
            throw JavaScriptRuntimeError.evaluationFailed("Unable to create JSContext")
        }

        var exceptionMessage: String?
        context.exceptionHandler = { _, exception in
            exceptionMessage = exception?.toString()
        }
        context.setObject(bridge, forKeyedSubscript: "Native" as NSString)

        #if DEBUG
        context.setObject(true, forKeyedSubscript: "__POKETOOL_DEBUG__" as NSString)
        #else
        context.setObject(false, forKeyedSubscript: "__POKETOOL_DEBUG__" as NSString)
        #endif

        let loaderCandidates = [
            Bundle.main.resourceURL?.appendingPathComponent("JavaScript/runtime/module-loader.js"),
            Bundle.main.resourceURL?.appendingPathComponent("runtime/module-loader.js"),
            Bundle.main.url(forResource: "module-loader", withExtension: "js")
        ].compactMap { $0 }
        guard let loaderURL = loaderCandidates.first(where: {
                  FileManager.default.fileExists(atPath: $0.path)
              }),
              let loaderSource = try? String(contentsOf: loaderURL, encoding: .utf8) else {
            throw JavaScriptRuntimeError.missingModuleLoader
        }
        context.evaluateScript(loaderSource, withSourceURL: URL(string: "poketool://runtime/module-loader.js"))
        if let exceptionMessage {
            throw JavaScriptRuntimeError.evaluationFailed(exceptionMessage)
        }
        context.evaluateScript("require('/bootstrap')")
        if let exceptionMessage {
            throw JavaScriptRuntimeError.evaluationFailed(exceptionMessage)
        }

        guard
            let value = context.evaluateScript("PokeToolRuntime.healthCheck()"),
            let dictionary = value.toDictionary(),
            dictionary["ok"] as? Bool == true,
            let version = dictionary["version"] as? String,
            let phase = dictionary["phase"] as? Int
        else {
            throw JavaScriptRuntimeError.invalidHealthResponse
        }

        self.context = context
        logger.log(.info, category: .runtime, message: "JavaScriptCore runtime started")
        return RuntimeHealth(version: version, phase: phase)
    }

    func stop() {
        context?.evaluateScript("__PokeToolModuleSystem && __PokeToolModuleSystem.stop()")
        bridge.stop()
        context?.exceptionHandler = nil
        context = nil
    }

    func startProductRun(tasksJSON: String, executorModuleID: String) async throws -> String {
        guard executorModuleID.hasPrefix("/modules/"),
              !executorModuleID.contains("\\"),
              !executorModuleID.contains("..") else {
            throw JavaScriptRuntimeError.evaluationFailed("Product executor module ID is invalid")
        }
        let tasksData = Data(tasksJSON.utf8)
        _ = try JSONSerialization.jsonObject(with: tasksData)
        let encodedTasksData = try JSONSerialization.data(
            withJSONObject: tasksJSON, options: [.fragmentsAllowed]
        )
        guard let encodedTasks = String(data: encodedTasksData, encoding: .utf8) else {
            throw JavaScriptRuntimeError.evaluationFailed("Task serialization failed")
        }
        let encodedModule = executorModuleID
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return try await runAsyncScript(
            """
            const product = require("/modules/product/index");
            const executor = require('\(encodedModule)');
            return await product.runner.start(JSON.parse(\(encodedTasks)), executor);
            """,
            timeout: 120
        )
    }

    func stopProductRun(reason: String = "Application requested stop") {
        let encoded = reason
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        context?.evaluateScript(
            "require('/modules/product/index').runner.stop('\(encoded)')"
        )
    }

    func productStateSnapshot() -> String {
        context?.evaluateScript(
            "JSON.stringify(require('/modules/product/index').core.current())"
        )?.toString() ?? "{}"
    }

    private func runAsyncScript(_ source: String, timeout: TimeInterval) async throws -> String {
        guard context != nil else {
            throw JavaScriptRuntimeError.evaluationFailed("Runtime is not started")
        }
        let marker = "__pokeToolProductAsyncResult"
        context?.evaluateScript(
            """
            this.\(marker) = "pending";
            (async function () {
              \(source)
            }).call(this).then(
              value => { this.\(marker) = JSON.stringify({ok:true,value:value}); },
              error => { this.\(marker) = JSON.stringify({
                ok:false,error:{name:error.name,code:error.code,message:error.message,
                  taskId:error.taskId,flowId:error.flowId,diagnostics:error.diagnostics}
              }); }
            );
            """
        )
        let iterations = Int(min(max(timeout, 0.1), 120) * 10)
        for _ in 0..<iterations {
            try Task.checkCancellation()
            if let result = context?.objectForKeyedSubscript(marker)?.toString(),
               result != "pending" {
                return result
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw JavaScriptRuntimeError.evaluationFailed("Product JavaScript operation timed out")
    }

    #if DEBUG
    func evaluateForTesting(_ source: String) -> JSValue? {
        context?.evaluateScript(source)
    }

    var activeTimerCountForTesting: Int { bridge.Runtime.activeTimerCount() }

    func runDebugBrowserBridgeHarness() async throws -> String {
        _ = try start()
        defer { stop() }
        let marker = "__pokeToolBridgeHarnessResult"
        context?.evaluateScript(
            """
            this.\(marker) = "pending";
            (async function () {
              let browser;
              try {
                browser = await PokeToolRuntime.browser.create();
                await browser.load("https://example.com");
                await browser.waitNavigation({type:"finished"}, {timeoutMs:20000});
                const result = {
                  browserId: browser.browserId,
                  title: await browser.title(),
                  readyState: await browser.readyState(),
                  hasBody: await browser.exists("body")
                };
                await browser.destroy();
                this.\(marker) = JSON.stringify({ok:true,result:result});
              } catch (error) {
                if (browser) { try { await browser.destroy(); } catch (_) {} }
                this.\(marker) = JSON.stringify({
                  ok:false,
                  error:{name:error.name,code:error.code,message:error.message,
                         operationId:error.operationId,browserId:error.browserId}
                });
              }
            }).call(this);
            """
        )
        for _ in 0..<300 {
            try Task.checkCancellation()
            if let result = context?.objectForKeyedSubscript(marker)?.toString(),
               result != "pending" {
                return result
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw JavaScriptRuntimeError.evaluationFailed("Debug bridge harness timed out")
    }

    func runAsyncTestScript(_ source: String, timeout: TimeInterval = 30) async throws -> String {
        try await runAsyncScript(source, timeout: timeout)
    }

    func runDebugWebCompatibilityHarness() async throws -> String {
        _ = try start()
        defer { stop() }
        return try await runAsyncTestScript(
            """
            let browser;
            try {
              browser = await PokeToolRuntime.browser.create();
              await browser.load("https://example.com");
              await PokeToolRuntime.web.waitPageReady(browser, 20000);
              await PokeToolRuntime.web.waitVisible(browser, "body", 15000);
              await PokeToolRuntime.web.waitText(browser, "Example Domain", 15000);
              const result = {
                title: await PokeToolRuntime.web.getTitle(browser),
                url: await PokeToolRuntime.web.getURL(browser)
              };
              await PokeToolRuntime.web.safeDestroy(browser);
              return result;
            } catch (error) {
              if (browser) await PokeToolRuntime.web.safeDestroy(browser);
              throw error;
            }
            """,
            timeout: 60
        )
    }

    func moduleDiagnostics() -> String {
        context?.evaluateScript("JSON.stringify(__PokeToolModuleSystem.diagnostics())")?.toString()
            ?? "{}"
    }

    func runDebugModuleSelfTest() throws -> String {
        guard let value = context?.evaluateScript(
            """
            (function () {
              const named = require("/modules/fixtures/named-exports");
              const replaced = require("/modules/fixtures/replace-module-exports");
              const circular = require("/modules/fixtures/circular-a");
              return JSON.stringify({
                named: named.answer, replaced: replaced.value,
                circular: circular.name, diagnostics: PokeToolRuntime.modules.graph()
              });
            })()
            """
        )?.toString() else {
            throw JavaScriptRuntimeError.evaluationFailed("Module self-test did not return a result")
        }
        return value
    }

    func runDebugInfrastructureHarness() async throws -> String {
        _ = try start()
        defer { stop() }
        return try await runAsyncTestScript(
            """
            const storage = require("/compat/storage-compat");
            const path = "/temp/debug-infrastructure.json";
            await storage.set("debug.infrastructure", {ok:true});
            await storage.writeJSON(path, {source:"debug",ok:true}, {overwrite:true});
            const result = {
              stored: await storage.get("debug.infrastructure"),
              file: await storage.readJSON(path),
              uuid: await PokeToolRuntime.system.uuid(),
              device: await PokeToolRuntime.device.info()
            };
            let eventPayload = null;
            const subscription = PokeToolRuntime.events.on("js.debug", value => { eventPayload = value; });
            await PokeToolRuntime.events.emit("js.debug", {delivered:true});
            PokeToolRuntime.events.off(subscription);
            await PokeToolRuntime.system.sleep(20);
            result.event = eventPayload;
            await storage.removePath(path);
            await storage.remove("debug.infrastructure");
            return result;
            """,
            timeout: 10
        )
    }
    #endif
}

@MainActor
final class JavaScriptRuntimeFactory: BusinessRuntimeFactory {
    private let bridgeFactory: NativeBridgeFactory
    private let logger: Logging

    init(bridgeFactory: NativeBridgeFactory, logger: Logging) {
        self.bridgeFactory = bridgeFactory
        self.logger = logger
    }

    func makeRuntime() -> BusinessRuntime {
        JavaScriptRuntime(bridge: bridgeFactory.makeBridge(), logger: logger)
    }
}
