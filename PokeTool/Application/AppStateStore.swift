import Combine
import Foundation

struct AppState: Equatable {
    enum RuntimeStatus: Equatable {
        case idle
        case ready(version: String)
        case failed(message: String)
    }

    var runtimeStatus: RuntimeStatus = .idle
    var activeURL: URL?
}

final class AppStateStore {
    @Published private(set) var state = AppState()

    var publisher: AnyPublisher<AppState, Never> {
        $state.eraseToAnyPublisher()
    }

    func update(_ mutation: (inout AppState) -> Void) {
        mutation(&state)
    }
}

