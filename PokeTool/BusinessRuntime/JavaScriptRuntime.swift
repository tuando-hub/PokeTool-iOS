import Foundation
import JavaScriptCore

enum JavaScriptRuntimeError: LocalizedError {
    case missingBootstrap
    case evaluationFailed(String)
    case invalidHealthResponse

    var errorDescription: String? {
        switch self {
        case .missingBootstrap: return "JavaScript bootstrap resource is missing."
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

        let bootstrapURL =
            Bundle.main.url(forResource: "bootstrap", withExtension: "js", subdirectory: "JavaScript")
            ?? Bundle.main.url(forResource: "bootstrap", withExtension: "js")

        guard let url = bootstrapURL,
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            throw JavaScriptRuntimeError.missingBootstrap
        }

        context.evaluateScript(source, withSourceURL: url)
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
        bridge.stop()
        context?.exceptionHandler = nil
        context = nil
    }

    #if DEBUG
    func evaluateForTesting(_ source: String) -> JSValue? {
        context?.evaluateScript(source)
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
