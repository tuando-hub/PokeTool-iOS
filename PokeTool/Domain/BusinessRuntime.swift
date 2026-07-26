import Foundation

struct RuntimeHealth: Equatable {
    let version: String
    let phase: Int
}

@MainActor
protocol BusinessRuntime: AnyObject {
    func start() throws -> RuntimeHealth
    func stop()
}

@MainActor
protocol BusinessRuntimeFactory {
    func makeRuntime() -> BusinessRuntime
}
