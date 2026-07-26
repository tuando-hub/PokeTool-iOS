import Foundation

/// Foundation only in Phase 2. Instrumentation is deliberately not reported as
/// operational until fetch/XHR lifecycle can be integration-tested on iOS.
protocol BrowserNetworkIdleOperating: AnyObject {
    func waitForIdle(
        browserId: BrowserID,
        idleThreshold: Int,
        quietDuration: TimeInterval,
        timeout: TimeInterval
    ) async throws
    func uninstall(browserId: BrowserID) async
}

struct BrowserSelectedFile: Hashable, Sendable {
    let url: URL
    let mimeType: String?
}

protocol BrowserFileSelecting: AnyObject {
    @MainActor
    func selectFiles(allowsMultiple: Bool, allowedTypes: [String]) async throws -> [BrowserSelectedFile]
}

enum BrowserProcessRecoveryPolicy: Sendable {
    case none
    case reloadOnce
}

protocol DownloadDestinationPolicy {
    func destination(suggestedFilename: String?) throws -> URL
}

final class ControlledDownloadDestinationPolicy: DownloadDestinationPolicy {
    private let directory: URL

    init(fileManager: FileManager = .default) {
        directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeTool/Downloads", isDirectory: true)
    }

    func destination(suggestedFilename: String?) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unsafe = suggestedFilename ?? "download"
        let name = URL(fileURLWithPath: unsafe).lastPathComponent
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        return directory.appendingPathComponent("\(UUID().uuidString)-\(name)")
    }
}

struct SensitiveDataRedactor {
    private let sensitiveKeys = [
        "authorization", "proxy-authorization", "cookie", "set-cookie",
        "password", "passwd", "pass", "token", "access_token", "refresh_token",
        "bearer", "secret", "otp", "verification_code", "card", "card_number",
        "cvv", "cvc", "pin", "pan"
    ]

    func redact(_ values: [String: String]) -> [String: String] {
        values.mapValues { $0 }.reduce(into: [:]) { output, item in
            output[item.key] = sensitiveKeys.contains(where: {
                item.key.localizedCaseInsensitiveContains($0)
            }) ? "<redacted>" : item.value
        }
    }
}

typealias BrowserRedactor = SensitiveDataRedactor
