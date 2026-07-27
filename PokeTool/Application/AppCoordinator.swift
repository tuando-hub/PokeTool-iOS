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
                runtimeFactory: container.runtimeFactory,
                productRuntimeService: container.productRuntimeService
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

        let tabs: [(UIViewController, String, String)] = [
            (dashboard, "Dashboard", "rectangle.grid.2x2.fill"),
            (WorkspaceViewController(title: "Tasks", subtitle: "Manage accounts and queued flows", icon: "checklist"), "Tasks", "checklist"),
            (WorkspaceViewController(title: "Results", subtitle: "History and run summaries", icon: "chart.bar.xaxis"), "Results", "chart.bar.xaxis"),
            (WorkspaceViewController(title: "Tools", subtitle: "Gateway, diagnostics and fixtures", icon: "wrench.and.screwdriver"), "Tools", "wrench.and.screwdriver"),
            (WorkspaceViewController(title: "Settings", subtitle: "App and Phone OTP configuration", icon: "gearshape"), "Settings", "gearshape")
        ]
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = tabs.enumerated().map { index, item in
            item.0.tabBarItem = UITabBarItem(title: item.1, image: UIImage(systemName: item.2), tag: index)
            return UINavigationController(rootViewController: item.0)
        }
        tabBarController.tabBar.tintColor = AppTheme.accent

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

private final class WorkspaceViewController: UIViewController {
    private let heading: String; private let subtitle: String; private let icon: String
    init(title: String, subtitle: String, icon: String) { self.heading = title; self.subtitle = subtitle; self.icon = icon; super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    override func viewDidLoad() { super.viewDidLoad(); title = heading; view.backgroundColor = AppTheme.background
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        let hero = AppTheme.cardView(); let iconView = UIImageView(image: UIImage(systemName: icon)); iconView.tintColor = AppTheme.accent; let titleLabel = UILabel(); titleLabel.text = heading; titleLabel.font = .preferredFont(forTextStyle: .title2); let sub = UILabel(); sub.text = subtitle; sub.textColor = AppTheme.muted; sub.numberOfLines = 0; let h = UIStackView(arrangedSubviews: [iconView, titleLabel, sub]); h.axis = .vertical; h.spacing = 8; h.translatesAutoresizingMaskIntoConstraints = false; hero.addSubview(h); NSLayoutConstraint.activate([h.topAnchor.constraint(equalTo: hero.topAnchor, constant: 20), h.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 20), h.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -20), h.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -20)]); let info = UILabel(); info.text = "Your workspace is ready\nConnect a task source to see live activity here."; info.textColor = AppTheme.muted; info.numberOfLines = 0; info.textAlignment = .center; stack.addArrangedSubview(hero); stack.addArrangedSubview(info); scroll.addSubview(stack); view.addSubview(scroll); NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor), stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)]) }
}
