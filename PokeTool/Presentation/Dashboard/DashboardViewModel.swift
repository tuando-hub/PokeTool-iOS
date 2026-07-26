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
