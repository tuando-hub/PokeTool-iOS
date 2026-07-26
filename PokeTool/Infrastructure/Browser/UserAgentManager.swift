import Foundation

enum UserAgentSelection: Equatable {
    case systemDefault
    case custom(String)
}

final class UserAgentManager {
    func resolve(_ selection: UserAgentSelection) -> String? {
        switch selection {
        case .systemDefault:
            return nil
        case .custom(let value):
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }
    }
}

