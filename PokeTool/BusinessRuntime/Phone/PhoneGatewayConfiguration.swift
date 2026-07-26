import Foundation

final class PhoneGatewayConfiguration {
    private let keychain: KeychainStoring
    private let defaults: UserDefaults
    private let baseURLKey = "phone.gateway.baseURL"
    private let apiKeyAccount = "phone.gateway.apiKey"
    init(keychain: KeychainStoring = KeychainStore(), defaults: UserDefaults = .standard) { self.keychain = keychain; self.defaults = defaults }
    var baseURL: String { get { defaults.string(forKey: baseURLKey) ?? "" } set { defaults.set(newValue, forKey: baseURLKey) } }
    var hasAPIKey: Bool { (try? keychain.data(account: apiKeyAccount)) != nil }
    func setAPIKey(_ value: String) throws { try keychain.set(Data(value.utf8), account: apiKeyAccount) }
    func apiKey() throws -> String { guard let data = try keychain.data(account: apiKeyAccount), let value = String(data: data, encoding: .utf8), !value.isEmpty else { return "" }; return value }
    func clear() throws { defaults.removeObject(forKey: baseURLKey); try keychain.remove(account: apiKeyAccount) }
    func makeProvider() throws -> RemotePhoneOtpProvider { try RemotePhoneOtpProvider(baseURL: baseURL, apiKey: apiKey()) }
}
