import Combine
import UIKit

final class DashboardViewController: UIViewController {
    private let viewModel: DashboardViewModel
    private var cancellables = Set<AnyCancellable>()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let runtimeLabel = UILabel()
    private let statusImageView = UIImageView()

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
        #if DEBUG
        navigationItem.rightBarButtonItems = [
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
    #endif

    private func configureUI() {
        title = "Dashboard"
        view.backgroundColor = .systemBackground

        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.font = .preferredFont(forTextStyle: .headline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.adjustsFontForContentSizeCategory = true

        runtimeLabel.font = .preferredFont(forTextStyle: .body)
        runtimeLabel.numberOfLines = 0
        runtimeLabel.adjustsFontForContentSizeCategory = true

        statusImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28)

        let runtimeRow = UIStackView(arrangedSubviews: [statusImageView, runtimeLabel])
        runtimeRow.axis = .horizontal
        runtimeRow.spacing = 12
        runtimeRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, runtimeRow])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    private func bind() {
        viewModel.$viewState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.titleLabel.text = state.title
                self?.subtitleLabel.text = state.subtitle
                self?.runtimeLabel.text = state.runtimeText
                self?.statusImageView.image = UIImage(
                    systemName: state.isHealthy ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                self?.statusImageView.tintColor = state.isHealthy ? .systemGreen : .systemOrange
            }
            .store(in: &cancellables)
    }
}
