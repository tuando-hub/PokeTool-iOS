import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?
    private var dependencyContainer: DependencyContainer?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let container = DependencyContainer()
        let coordinator = AppCoordinator(window: window, container: container)

        self.window = window
        self.dependencyContainer = container
        self.appCoordinator = coordinator
        coordinator.start()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let browserManager = dependencyContainer?.browserManager else { return }
        Task { @MainActor in
            await browserManager.destroyAllSessions()
        }
    }
}
