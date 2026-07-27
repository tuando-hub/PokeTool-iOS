import Combine
import UIKit

final class DashboardViewController: UIViewController {
    private let viewModel: DashboardViewModel
    private var cancellables = Set<AnyCancellable>()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusLabel = UILabel()
    private let runtimeLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let metrics = UIStackView()

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Storyboard initialization is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        bind()
        viewModel.start()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(openPhoneGateway))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Tasks", style: .plain, target: self, action: #selector(runPokemonTasks))
        #if DEBUG
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "JCS", style: .plain, target: self, action: #selector(runJumpCSSliceTest)),
            UIBarButtonItem(
                title: "Jump+", style: .plain,
                target: self, action: #selector(runJumpPlusSliceTest)
            ),
            UIBarButtonItem(
                title: "Pokemon", style: .plain,
                target: self, action: #selector(runPokemonSliceTest)
            ),
            UIBarButtonItem(
                title: "Stop", style: .plain,
                target: self, action: #selector(stopProductFlowTest)
            ),
            UIBarButtonItem(
                title: "Product Flow", style: .plain,
                target: self, action: #selector(runProductFlowTest)
            ),
            UIBarButtonItem(
                title: "Infrastructure", style: .plain,
                target: self, action: #selector(runInfrastructureTest)
            ),
            UIBarButtonItem(
                title: "Modules", style: .plain,
                target: self, action: #selector(runModuleInspector)
            ),
            UIBarButtonItem(
                title: "Web Compat Test", style: .plain,
                target: self, action: #selector(runWebCompatTest)
            ),
            UIBarButtonItem(
                title: "JS Bridge Test", style: .plain,
                target: self, action: #selector(runBridgeTest)
            )
        ]
        #endif
    }

    @objc private func openPhoneGateway() { navigationController?.pushViewController(PhoneGatewayViewController(), animated: true) }

    @objc private func runPokemonTasks() {
        let alert = UIAlertController(
            title: "Run Pokemon tasks",
            message: "Paste a validated JSON task array. Credentials stay in memory and are not logged.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "[{\"id\":\"...\",\"mode\":\"pokemon...\"}]"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Run", style: .default) { [weak self, weak alert] _ in
            guard let json = alert?.textFields?.first?.text, !json.isEmpty else { return }
            Task { @MainActor [weak self] in await self?.viewModel.runPokemonTasks(json: json) }
        })
        present(alert, animated: true)
    }

    @objc private func stopPokemonTasks() {
        viewModel.stopPokemonTasks()
    }

    @objc private func runJumpPlusTasks() {
        let alert = UIAlertController(
            title: "Run Jump+ tasks",
            message: "Paste a Jump+ JSON task array. Final submit is disabled unless explicitly true.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "[{\"id\":\"...\",\"mode\":\"jumpplus...\"}]"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Run", style: .default) { [weak self, weak alert] _ in
            guard let json = alert?.textFields?.first?.text, !json.isEmpty else { return }
            Task { @MainActor [weak self] in await self?.viewModel.runJumpPlusTasks(json: json) }
        })
        present(alert, animated: true)
    }

    @objc private func runJumpCSTasks() {
        let alert = UIAlertController(title: "Run JumpCS tasks", message: "Paste JumpCS JSON. Phone provider and final order submit require explicit configuration.", preferredStyle: .alert)
        alert.addTextField { field in field.placeholder = "[{\"id\":\"...\",\"mode\":\"jumpcs.buy\"}]"; field.autocapitalizationType = .none; field.autocorrectionType = .no; field.isSecureTextEntry = true }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Run", style: .default) { [weak self, weak alert] _ in
            guard let json = alert?.textFields?.first?.text, !json.isEmpty else { return }
            Task { @MainActor [weak self] in await self?.viewModel.runJumpCSTasks(json: json) }
        })
        present(alert, animated: true)
    }

    #if DEBUG
    @objc private func runBridgeTest() {
        Task { @MainActor [weak self] in await self?.viewModel.runBridgeTest() }
    }

    @objc private func runWebCompatTest() {
        Task { @MainActor [weak self] in await self?.viewModel.runWebCompatTest() }
    }

    @objc private func runModuleInspector() {
        viewModel.runModuleInspector()
    }

    @objc private func runInfrastructureTest() {
        Task { @MainActor [weak self] in await self?.viewModel.runInfrastructureTest() }
    }

    @objc private func runPokemonSliceTest() {
        Task { @MainActor [weak self] in await self?.viewModel.runPokemonSliceTest() }
    }

    @objc private func runJumpPlusSliceTest() {
        Task { @MainActor [weak self] in await self?.viewModel.runJumpPlusSliceTest() }
    }

    @objc private func runJumpCSSliceTest() { Task { @MainActor [weak self] in await self?.viewModel.runJumpCSSliceTest() } }

    @objc private func runProductFlowTest() {
        Task { @MainActor [weak self] in await self?.viewModel.runProductFlowTest() }
    }

    @objc private func stopProductFlowTest() {
        viewModel.stopProductFlowTest()
    }
    #endif

    private func configureUI() {
        title = "Dashboard"
        view.backgroundColor = AppTheme.background

        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true

        runtimeLabel.font = .preferredFont(forTextStyle: .body)
        runtimeLabel.numberOfLines = 0
        runtimeLabel.adjustsFontForContentSizeCategory = true

        statusLabel.font = .preferredFont(forTextStyle: .caption1); statusLabel.textAlignment = .center; statusLabel.layer.cornerRadius = 9; statusLabel.clipsToBounds = true
        progressView.progressTintColor = AppTheme.accent; progressView.trackTintColor = AppTheme.border
        metrics.axis = .horizontal; metrics.spacing = 8; metrics.distribution = .fillEqually
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel]); header.axis = .vertical; header.spacing = 4
        let hero = AppTheme.cardView(); let heroStack = UIStackView(arrangedSubviews: [statusLabel, runtimeLabel, progressView]); heroStack.axis = .vertical; heroStack.spacing = 12; heroStack.translatesAutoresizingMaskIntoConstraints = false; hero.addSubview(heroStack)
        NSLayoutConstraint.activate([heroStack.topAnchor.constraint(equalTo: hero.topAnchor, constant: 16), heroStack.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 16), heroStack.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -16), heroStack.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -16)])
        ["Total\n12", "Success\n8", "Failed\n1", "Stopped\n0"].forEach { text in let l = UILabel(); l.text = text; l.numberOfLines = 2; l.textAlignment = .center; l.font = .preferredFont(forTextStyle: .headline); let c = AppTheme.cardView(); c.addSubview(l); l.translatesAutoresizingMaskIntoConstraints = false; NSLayoutConstraint.activate([l.topAnchor.constraint(equalTo: c.topAnchor, constant: 12), l.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4), l.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4), l.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -12)]); metrics.addArrangedSubview(c) }
        let current = AppTheme.cardView(); let currentLabel = UILabel(); currentLabel.text = "CURRENT TASK\nJumpCS · DEMO_ACCOUNT_01\nProfile verification  ·  67%\nWaiting for phone OTP"; currentLabel.numberOfLines = 0; currentLabel.font = .preferredFont(forTextStyle: .callout); currentLabel.translatesAutoresizingMaskIntoConstraints = false; current.addSubview(currentLabel); NSLayoutConstraint.activate([currentLabel.topAnchor.constraint(equalTo: current.topAnchor, constant: 16), currentLabel.leadingAnchor.constraint(equalTo: current.leadingAnchor, constant: 16), currentLabel.trailingAnchor.constraint(equalTo: current.trailingAnchor, constant: -16), currentLabel.bottomAnchor.constraint(equalTo: current.bottomAnchor, constant: -16)])
        let activity = AppTheme.cardView(); let activityLabel = UILabel(); activityLabel.text = "RECENT ACTIVITY\n✓  09:42  Login verified\n●  09:41  Waiting for OTP\n✓  09:40  Gateway connected"; activityLabel.numberOfLines = 0; activityLabel.font = .preferredFont(forTextStyle: .subheadline); activityLabel.translatesAutoresizingMaskIntoConstraints = false; activity.addSubview(activityLabel); NSLayoutConstraint.activate([activityLabel.topAnchor.constraint(equalTo: activity.topAnchor, constant: 16), activityLabel.leadingAnchor.constraint(equalTo: activity.leadingAnchor, constant: 16), activityLabel.trailingAnchor.constraint(equalTo: activity.trailingAnchor, constant: -16), activityLabel.bottomAnchor.constraint(equalTo: activity.bottomAnchor, constant: -16)])
        [header, hero, metrics, current, activity].forEach { stack.addArrangedSubview($0) }; scroll.addSubview(stack); view.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor), stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
    }

    private func bind() {
        viewModel.$viewState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.titleLabel.text = state.title
                self?.subtitleLabel.text = state.subtitle
                self?.runtimeLabel.text = state.runtimeText
                self?.statusLabel.text = state.isHealthy ? "  READY  " : "  ATTENTION  "
                self?.statusLabel.textColor = state.isHealthy ? AppTheme.success : AppTheme.warning
                self?.statusLabel.backgroundColor = (state.isHealthy ? AppTheme.success : AppTheme.warning).withAlphaComponent(0.16)
                self?.progressView.progress = state.isHealthy ? 0.72 : 0.18
            }
            .store(in: &cancellables)
    }
}
