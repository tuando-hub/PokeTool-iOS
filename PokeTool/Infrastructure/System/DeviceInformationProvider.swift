import Foundation
import UIKit

@MainActor
final class DeviceInformationProvider: DeviceInformationProviding {
    func info() -> SafeDeviceInfo {
        let device = UIDevice.current
        let screen = UIScreen.main
        return SafeDeviceInfo(
            platform: "iOS",
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            modelCategory: device.userInterfaceIdiom == .pad ? "tablet" : "phone",
            screenWidth: screen.bounds.width,
            screenHeight: screen.bounds.height,
            displayScale: screen.scale,
            locale: Locale.current.identifier,
            preferredLanguages: Locale.preferredLanguages,
            timeZone: TimeZone.current.identifier,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: String(describing: ProcessInfo.processInfo.thermalState)
        )
    }
}
