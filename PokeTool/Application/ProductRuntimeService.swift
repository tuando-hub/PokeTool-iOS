import Foundation

struct ProductRunSummary: Decodable {
    let total: Int
    let succeeded: Int
    let failed: Int
    let cancelled: Int
    let skipped: Int
    let durationMs: Double
}

@MainActor
final class ProductRuntimeService {
    private let runtimeFactory: BusinessRuntimeFactory
    private var runtime: JavaScriptRuntime?
    private(set) var isRunning = false

    init(runtimeFactory: BusinessRuntimeFactory) {
        self.runtimeFactory = runtimeFactory
    }

    func start(tasksJSON: String, executorModuleID: String) async throws -> ProductRunSummary {
        guard !isRunning else {
            throw JavaScriptRuntimeError.evaluationFailed("Product runtime is already running")
        }
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else {
            throw JavaScriptRuntimeError.evaluationFailed("Product runtime is unavailable")
        }
        self.runtime = runtime
        isRunning = true
        do {
            _ = try runtime.start()
            let response = try await runtime.startProductRun(
                tasksJSON: tasksJSON, executorModuleID: executorModuleID
            )
            let envelope = try JSONDecoder().decode(
                ProductRunEnvelope.self, from: Data(response.utf8)
            )
            guard envelope.ok, let summary = envelope.value else {
                throw JavaScriptRuntimeError.evaluationFailed(
                    envelope.error?.message ?? "Product run failed"
                )
            }
            runtime.stop()
            self.runtime = nil
            isRunning = false
            return summary
        } catch {
            runtime.stop()
            self.runtime = nil
            isRunning = false
            throw error
        }
    }

    func stop(reason: String = "User requested stop") {
        runtime?.stopProductRun(reason: reason)
    }

    func stateSnapshot() -> String {
        runtime?.productStateSnapshot() ?? "{}"
    }

    private struct ProductRunEnvelope: Decodable {
        struct Failure: Decodable { let message: String }
        let ok: Bool
        let value: ProductRunSummary?
        let error: Failure?
    }
}
