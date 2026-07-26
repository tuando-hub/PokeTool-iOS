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
    private var cancellables = Set<AnyCancellable>()

    init(stateStore: AppStateStore, runtimeFactory: BusinessRuntimeFactory) {
        self.stateStore = stateStore
        self.runtimeFactory = runtimeFactory

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
