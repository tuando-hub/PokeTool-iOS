import BackgroundTasks
import Foundation
import UIKit

final class BackgroundService {
    func beginTask(named name: String, expiration: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
        UIApplication.shared.beginBackgroundTask(withName: name, expirationHandler: expiration)
    }

    func endTask(_ identifier: UIBackgroundTaskIdentifier) {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }
}
