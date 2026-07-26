import Foundation

struct RuntimeHealth: Equatable {
    let version: String
    let phase: Int
}

protocol BusinessRuntime: AnyObject {
    func start() throws -> RuntimeHealth
    func stop()
}

