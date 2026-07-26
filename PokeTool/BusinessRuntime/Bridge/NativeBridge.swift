import Foundation
import JavaScriptCore

@objc protocol NativeBridgeExport: JSExport {
    func log(_ level: String, _ message: String)
    func appVersion() -> String
}

final class NativeBridge: NSObject, NativeBridgeExport {
    private let browser: BrowserAutomating
    private let fileStore: FileStore
    private let network: NetworkClient
    private let keychain: KeychainStore

    init(
        browser: BrowserAutomating,
        fileStore: FileStore,
        network: NetworkClient,
        keychain: KeychainStore
    ) {
        self.browser = browser
        self.fileStore = fileStore
        self.network = network
        self.keychain = keychain
    }

    func log(_ level: String, _ message: String) {
        Logger.shared.write(level: level, message: message)
    }

    func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
