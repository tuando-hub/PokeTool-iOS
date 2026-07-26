import XCTest
@testable import PokeTool

final class InfrastructureBridgeTests: XCTestCase {
    func testManagedStorageRejectsTraversalAndSupportsAtomicOperations() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PokeToolTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileStore(rootURL: root)
        try await store.write("/data/value.txt", data: Data("hello".utf8))
        XCTAssertEqual(String(data: try await store.read("/data/value.txt"), encoding: .utf8), "hello")
        await XCTAssertThrowsErrorAsync {
            try await store.write("/data/value.txt", data: Data(), overwrite: false)
        }
        await XCTAssertThrowsErrorAsync { _ = try await store.read("/data/../../outside") }
        try await store.copy("/data/value.txt", to: "/results/copy.txt", overwrite: false)
        let copiedExists = try await store.exists("/results/copy.txt")
        XCTAssertTrue(copiedExists)
        try await store.move("/results/copy.txt", to: "/results/moved.txt", overwrite: false)
        let originalExists = try await store.exists("/results/copy.txt")
        XCTAssertFalse(originalExists)
        try await store.removePath("/results/moved.txt")
    }

    @MainActor
    func testInfrastructureCompatibilityEndToEnd() async throws {
        let runtime = try makeRuntime()
        defer { runtime.stop() }
        let result = try await runtime.runAsyncTestScript(
            """
            const storage = require("/compat/storage-compat");
            await storage.set("phase6.example", {enabled:true,count:2});
            const value = await storage.get("phase6.example");
            const path = "/temp/phase6-" + (await PokeToolRuntime.system.uuid()) + ".json";
            await storage.writeJSON(path, value);
            const file = await storage.readJSON(path);
            const exists = await storage.exists(path);
            const id = await PokeToolRuntime.system.uuid();
            await PokeToolRuntime.system.sleep(20);
            const info = await PokeToolRuntime.device.info();
            let delivered = null;
            const subscription = PokeToolRuntime.events.on("js.test", payload => { delivered = payload; });
            await PokeToolRuntime.events.emit("js.test", {ok:true});
            PokeToolRuntime.events.off(subscription);
            const oncePromise = PokeToolRuntime.events.once("js.once", {timeoutMs:1000});
            await PokeToolRuntime.events.emit("js.once", {once:true});
            const once = await oncePromise;
            let networkCode = null;
            try { await PokeToolRuntime.network.get("file:///private/test"); }
            catch (error) { networkCode = error.code; }
            await storage.removePath(path);
            await storage.remove("phase6.example");
            return {
              value, file, exists, uuidLength:id.length, platform:info.platform,
              delivered, once:once.payload, networkCode,
              web:typeof PokeToolRuntime.web.waitVisible,
              modules:PokeToolRuntime.modules.capabilities().commonJS,
              globals:[typeof $cache,typeof $file,typeof $http,typeof $device]
            };
            """,
            timeout: 10
        )
        let object = try valueObject(result)
        XCTAssertEqual((object["value"] as? [String: Any])?["enabled"] as? Bool, true)
        XCTAssertEqual((object["file"] as? [String: Any])?["count"] as? Int, 2)
        XCTAssertEqual(object["exists"] as? Bool, true)
        XCTAssertEqual(object["uuidLength"] as? Int, 36)
        XCTAssertEqual(object["platform"] as? String, "iOS")
        XCTAssertEqual((object["delivered"] as? [String: Any])?["ok"] as? Bool, true)
        XCTAssertEqual((object["once"] as? [String: Any])?["once"] as? Bool, true)
        XCTAssertEqual(object["networkCode"] as? String, "NETWORK_INVALID_URL")
        XCTAssertEqual(object["web"] as? String, "function")
        XCTAssertEqual(object["modules"] as? Bool, true)
        XCTAssertEqual(object["globals"] as? [String], ["undefined", "undefined", "undefined", "undefined"])
    }

    @MainActor
    func testCapabilitiesVersionsAndRuntimeStopCancellation() throws {
        let runtime = try makeRuntime()
        XCTAssertEqual(runtime.evaluateForTesting("Native.Storage.version")?.toString(), "1.0.0")
        XCTAssertEqual(runtime.evaluateForTesting("Native.Network.capabilities().https")?.toBool(), true)
        XCTAssertEqual(runtime.evaluateForTesting("Native.Device.capabilities().hardwareIdentifiers")?.toBool(), false)
        XCTAssertEqual(runtime.evaluateForTesting("PokeToolRuntime.infrastructure.version")?.toString(), "1.0.0")
        XCTAssertEqual(
            runtime.evaluateForTesting("PokeToolRuntime.system.sleep(10000) instanceof Promise")?.toBool(),
            true
        )
        runtime.stop()
        XCTAssertNil(runtime.evaluateForTesting("1"))
    }

    @MainActor
    func testNetworkServiceUsesTypedSerializableResponseAndHTTPPolicy() async throws {
        let responseURL = try XCTUnwrap(URL(string: "https://example.test/data"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: responseURL,
                statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        let service = NetworkBridgeService(
            client: StubNetworkTransport(
                data: Data(#"{"ok":true}"#.utf8), response: response
            ),
            limits: InfrastructureResourceLimits()
        )
        let value = try await service.perform(
            method: "request",
            arguments: [[
                "url": "https://example.test/data",
                "method": "GET",
                "responseType": "json"
            ]]
        )
        let object = try XCTUnwrap(value as? [String: Any])
        XCTAssertEqual(object["statusCode"] as? Int, 200)
        XCTAssertEqual((object["body"] as? [String: Any])?["ok"] as? Bool, true)

        do {
            _ = try await service.perform(
                method: "request", arguments: [["url": "file:///tmp/test"]]
            )
            XCTFail("Expected invalid URL")
        } catch let error as InfrastructureBridgeError {
            XCTAssertEqual(error.code, "NETWORK_INVALID_URL")
            XCTAssertFalse(error.message.contains("/tmp"))
        }
    }

    @MainActor
    func testKeychainServiceUsesAbstractionWithoutLeakingSecret() async throws {
        let store = StubKeychainStore()
        let service = KeychainBridgeService(
            store: store, limits: InfrastructureResourceLimits()
        )
        _ = try await service.perform(method: "set", arguments: ["credential", "top-secret"])
        let value = try await service.perform(method: "get", arguments: ["credential"])
        XCTAssertEqual(value as? String, "top-secret")
        let contains = try await service.perform(method: "contains", arguments: ["credential"])
        XCTAssertEqual(contains as? Bool, true)
        _ = try await service.perform(method: "remove", arguments: ["credential"])
        let missing = try await service.perform(method: "get", arguments: ["credential"])
        XCTAssertTrue(missing is NSNull)
    }

    @MainActor
    private func makeRuntime() throws -> JavaScriptRuntime {
        let runtime = try XCTUnwrap(
            DependencyContainer().runtimeFactory.makeRuntime() as? JavaScriptRuntime
        )
        XCTAssertEqual(try runtime.start().phase, 6)
        return runtime
    }

    private func valueObject(_ result: String) throws -> [String: Any] {
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
        )
        XCTAssertEqual(root["ok"] as? Bool, true, result)
        return try XCTUnwrap(root["value"] as? [String: Any])
    }
}

private final class StubNetworkTransport: NetworkTransporting {
    let dataValue: Data
    let response: HTTPURLResponse
    init(data: Data, response: HTTPURLResponse) {
        dataValue = data
        self.response = response
    }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (dataValue, response)
    }
}

private final class StubKeychainStore: KeychainStoring {
    private var values: [String: Data] = [:]
    func set(_ data: Data, account: String) throws { values[account] = data }
    func data(account: String) throws -> Data? { values[account] }
    func remove(account: String) throws { values[account] = nil }
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync(
        _ expression: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("Expected error", file: file, line: line)
        } catch {}
    }
}
