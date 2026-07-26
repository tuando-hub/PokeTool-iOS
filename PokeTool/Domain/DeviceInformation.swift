import Foundation

struct SafeDeviceInfo: Codable {
    let platform: String
    let systemName: String
    let systemVersion: String
    let modelCategory: String
    let screenWidth: Double
    let screenHeight: Double
    let displayScale: Double
    let locale: String
    let preferredLanguages: [String]
    let timeZone: String
    let lowPowerMode: Bool
    let thermalState: String
}

@MainActor
protocol DeviceInformationProviding {
    func info() -> SafeDeviceInfo
}
