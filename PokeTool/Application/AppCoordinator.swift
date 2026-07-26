import UIKit

@MainActor
final class AppCoordinator {
    private let window: UIWindow
    private let container: DependencyContainer

    init(window: UIWindow, container: DependencyContainer) {
        self.window = window
        self.container = container
    }

    func start() {
        let dashboard = DashboardViewController(
            viewModel: DashboardViewModel(
                stateStore: container.appStateStore,
                runtimeFactory: container.runtimeFactory
            )
        )
        dashboard.tabBarItem = UITabBarItem(
            title: "Dashboard",
            image: UIImage(systemName: "gauge.with.dots.needle.50percent"),
            tag: 0
        )

        let browser = BrowserViewController(
            viewModel: BrowserViewModel(browserManager: container.browserManager)
        )
        browser.tabBarItem = UITabBarItem(
            title: "Browser",
            image: UIImage(systemName: "globe"),
            tag: 1
        )

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            UINavigationController(rootViewController: dashboard),
            UINavigationController(rootViewController: browser)
        ]
        tabBarController.tabBar.tintColor = .systemIndigo

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}
