import Combine
import Foundation

@MainActor
final class DashboardViewModel {
    struct ViewState: Equatable {
        var title = "PokeTool"
        var subtitle = "Browser Automation Platform"
        var runtimeText = "Runtime not started"
        var isHealthy = false
    }

    @Published private(set) var viewState = ViewState()

    private let stateStore: AppStateStore
    private let runtimeFactory: BusinessRuntimeFactory
    private let productRuntimeService: ProductRuntimeService
    private var cancellables = Set<AnyCancellable>()

    init(
        stateStore: AppStateStore,
        runtimeFactory: BusinessRuntimeFactory,
        productRuntimeService: ProductRuntimeService
    ) {
        self.stateStore = stateStore
        self.runtimeFactory = runtimeFactory
        self.productRuntimeService = productRuntimeService

        stateStore.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    func start() {
        do {
            let runtime = runtimeFactory.makeRuntime()
            let health = try runtime.start()
            runtime.stop()
            stateStore.update {
                $0.runtimeStatus = .ready(version: health.version)
            }
        } catch {
            stateStore.update {
                $0.runtimeStatus = .failed(message: error.localizedDescription)
            }
        }
    }

    func runPokemonTasks(json: String) async {
        viewState.runtimeText = "Pokemon run: validating..."
        do {
            let summary = try await productRuntimeService.start(
                tasksJSON: json,
                executorModuleID: "/modules/pokemon/pokemon-executor"
            )
            viewState.runtimeText =
                "Pokemon run: total=\(summary.total) succeeded=\(summary.succeeded) " +
                "failed=\(summary.failed) cancelled=\(summary.cancelled) " +
                "duration=\(summary.durationMs)ms"
            viewState.isHealthy = summary.failed == 0 && summary.cancelled == 0
        } catch {
            viewState.runtimeText = "Pokemon run failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func stopPokemonTasks() {
        productRuntimeService.stop(reason: "User requested stop")
        viewState.runtimeText = "Pokemon run: cancellation requested"
    }

    func runJumpPlusTasks(json: String) async {
        viewState.runtimeText = "Jump+ run: validating..."
        do {
            let summary = try await productRuntimeService.start(
                tasksJSON: json,
                executorModuleID: "/modules/jumpplus/jumpplus-executor"
            )
            viewState.runtimeText =
                "Jump+ run: total=\(summary.total) succeeded=\(summary.succeeded) " +
                "failed=\(summary.failed) cancelled=\(summary.cancelled) duration=\(summary.durationMs)ms"
            viewState.isHealthy = summary.failed == 0 && summary.cancelled == 0
        } catch {
            viewState.runtimeText = "Jump+ run failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func stopJumpPlusTasks() {
        productRuntimeService.stop(reason: "User requested Jump+ stop")
        viewState.runtimeText = "Jump+ run: cancellation requested"
    }

    func runJumpCSTasks(json: String) async {
        viewState.runtimeText = "JumpCS run: validating..."
        do {
            let summary = try await productRuntimeService.start(tasksJSON: json, executorModuleID: "/modules/jumpcs/jumpcs-executor")
            viewState.runtimeText = "JumpCS run: total=\(summary.total) succeeded=\(summary.succeeded) failed=\(summary.failed) cancelled=\(summary.cancelled) duration=\(summary.durationMs)ms"
            viewState.isHealthy = summary.failed == 0 && summary.cancelled == 0
        } catch { viewState.runtimeText = "JumpCS run failed: \(error.localizedDescription)"; viewState.isHealthy = false }
    }

    func stopJumpCSTasks() { productRuntimeService.stop(reason: "User requested JumpCS stop"); viewState.runtimeText = "JumpCS run: cancellation requested" }

    #if DEBUG
    func runBridgeTest() async {
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else {
            viewState.runtimeText = "JS Bridge Test: runtime unavailable"
            return
        }
        viewState.runtimeText = "JS Bridge Test: running..."
        do {
            viewState.runtimeText = "JS Bridge Test: \(try await runtime.runDebugBrowserBridgeHarness())"
            viewState.isHealthy = true
        } catch {
            viewState.runtimeText = "JS Bridge Test failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func runWebCompatTest() async {
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else {
            viewState.runtimeText = "Web Compat Test: runtime unavailable"
            return
        }
        viewState.runtimeText = "Web Compat Test: running..."
        do {
            viewState.runtimeText = "Web Compat Test: \(try await runtime.runDebugWebCompatibilityHarness())"
            viewState.isHealthy = true
        } catch {
            viewState.runtimeText = "Web Compat Test failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func runModuleInspector() {
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else {
            viewState.runtimeText = "Module Inspector: runtime unavailable"
            return
        }
        do {
            _ = try runtime.start()
            let selfTest = try runtime.runDebugModuleSelfTest()
            let diagnostics = runtime.moduleDiagnostics()
            runtime.stop()
            viewState.runtimeText = "Module Inspector\nSelf-test: \(selfTest)\nDiagnostics: \(diagnostics)"
            viewState.isHealthy = true
        } catch {
            runtime.stop()
            viewState.runtimeText = "Module Inspector failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func runInfrastructureTest() async {
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else {
            viewState.runtimeText = "Infrastructure Test: runtime unavailable"
            return
        }
        viewState.runtimeText = "Infrastructure Test: running..."
        do {
            viewState.runtimeText = "Infrastructure Test: \(try await runtime.runDebugInfrastructureHarness())"
            viewState.isHealthy = true
        } catch {
            viewState.runtimeText = "Infrastructure Test failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func runPokemonSliceTest() async {
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else {
            viewState.runtimeText = "Pokemon Slice Test: runtime unavailable"
            return
        }
        viewState.runtimeText = "Pokemon Slice Test: running..."
        do {
            viewState.runtimeText = "Pokemon Slice Test: \(try await runtime.runDebugPokemonSliceHarness())"
            viewState.isHealthy = true
        } catch {
            viewState.runtimeText = "Pokemon Slice Test failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func runJumpPlusSliceTest() async {
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else {
            viewState.runtimeText = "Jump+ Slice Test: runtime unavailable"
            return
        }
        viewState.runtimeText = "Jump+ Slice Test: running..."
        do {
            viewState.runtimeText = "Jump+ Slice Test: \(try await runtime.runDebugJumpPlusSliceHarness())"
            viewState.isHealthy = true
        } catch {
            viewState.runtimeText = "Jump+ Slice Test failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func runJumpCSSliceTest() async {
        guard let runtime = runtimeFactory.makeRuntime() as? JavaScriptRuntime else { viewState.runtimeText = "JumpCS Slice Test: runtime unavailable"; return }
        viewState.runtimeText = "JumpCS Slice Test: running..."
        do { viewState.runtimeText = "JumpCS Slice Test: \(try await runtime.runDebugJumpCSSliceHarness())"; viewState.isHealthy = true }
        catch { viewState.runtimeText = "JumpCS Slice Test failed: \(error.localizedDescription)"; viewState.isHealthy = false }
    }

    func runProductFlowTest() async {
        viewState.runtimeText = "Product Flow Test: running..."
        do {
            let tasks = """
            [{"id":"fixture-success","mode":"fixture","payload":{"outcome":"success"}}]
            """
            let summary = try await productRuntimeService.start(
                tasksJSON: tasks,
                executorModuleID: "/modules/fixtures/product-flow-executor"
            )
            viewState.runtimeText =
                "Product Flow Test: total=\(summary.total) succeeded=\(summary.succeeded) " +
                "failed=\(summary.failed) cancelled=\(summary.cancelled) duration=\(summary.durationMs)ms"
            viewState.isHealthy = summary.succeeded == 1
        } catch {
            viewState.runtimeText = "Product Flow Test failed: \(error.localizedDescription)"
            viewState.isHealthy = false
        }
    }

    func stopProductFlowTest() {
        productRuntimeService.stop(reason: "Debug user requested stop")
        viewState.runtimeText = "Product Flow Test: cancellation requested\n" +
            productRuntimeService.stateSnapshot()
    }
    #endif

    private func render(_ state: AppState) {
        switch state.runtimeStatus {
        case .idle:
            viewState.runtimeText = "Runtime not started"
            viewState.isHealthy = false
        case .ready(let version):
            viewState.runtimeText = "JavaScriptCore ready · \(version)"
            viewState.isHealthy = true
        case .failed(let message):
            viewState.runtimeText = "Runtime error · \(message)"
            viewState.isHealthy = false
        }
    }
}
