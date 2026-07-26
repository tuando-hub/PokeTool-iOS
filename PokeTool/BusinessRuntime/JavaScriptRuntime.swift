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

final class JavaScriptRuntime: BusinessRuntime {
    private let bridge: NativeBridge
    private var context: JSContext?

    init(bridge: NativeBridge) {
        self.bridge = bridge
    }

    func start() throws -> RuntimeHealth {
        stop()

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
        return RuntimeHealth(version: version, phase: phase)
    }

    func stop() {
        context?.exceptionHandler = nil
        context = nil
    }
}
