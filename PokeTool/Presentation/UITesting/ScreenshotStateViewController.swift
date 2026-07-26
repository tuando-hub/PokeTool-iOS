import UIKit

final class ScreenshotStateViewController: UIViewController {
    private let state: String
    init(state: String) { self.state = state; super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 18; stack.alignment = .fill; stack.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel(); title.text = "PokeTool"; title.font = .preferredFont(forTextStyle: .largeTitle); title.accessibilityIdentifier = "dashboard.screen"
        let stateLabel = UILabel(); stateLabel.text = stateTitle(); stateLabel.font = .preferredFont(forTextStyle: .title2); stateLabel.numberOfLines = 0
        let detail = UILabel(); detail.text = "DEMO_ACCOUNT_01  •  user***@example.com\nMock / fixture mode • no live credentials"; detail.textColor = .secondaryLabel; detail.numberOfLines = 0
        let progress = UIProgressView(progressViewStyle: .default); progress.progress = state == "dashboardSuccess" ? 1 : (state == "dashboardRunning" || state == "phoneOtpWaiting" ? 0.56 : 0.18)
        let action = UIButton(configuration: .filled()); action.configuration?.title = state == "dashboardRunning" ? "STOP" : "RUN"; action.accessibilityIdentifier = state == "dashboardRunning" ? "dashboard.stopButton" : "dashboard.runButton"
        let card = UILabel(); card.text = stateDetail(); card.backgroundColor = .secondarySystemGroupedBackground; card.layer.cornerRadius = 12; card.clipsToBounds = true; card.textAlignment = .center; card.numberOfLines = 0; card.font = .preferredFont(forTextStyle: .body); card.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        [title, stateLabel, detail, progress, action, card].forEach { stack.addArrangedSubview($0) }; scroll.addSubview(stack); view.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor), stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
    }
    private func stateTitle() -> String { state.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
    private func stateDetail() -> String { switch state { case "phoneOtpWaiting": return "PHONE OTP\nWaiting for phone number…\nGateway: Mock • Order: DEMO-ORDER"; case "threeDSWaiting": return "3DS VERIFICATION\nWaiting for user action\nFinal submit disabled"; case "dashboardError": return "ERROR\nNetwork timeout handled safely\nNo secrets exposed"; case "dashboardStopped": return "STOPPED\nCleanup completed\nNo pending operations"; case "dashboardSuccess": return "COMPLETED\nAll mock steps verified\n0 failures"; case "modeSelection": return "Pokémon Center\nJump+\nJump Characters Store\nTools"; case "taskInput": return "Task input\nDEMO_ACCOUNT_01\nMode: jumpcs.validatePhoneOtp"; case "resultsHistory": return "Results\nSUCCESS  jumpcs.validatePhoneOtp\nSTOPPED  pokemon.lottery"; case "smokeTests", "smokeTestResult": return "Developer Tools\n✓ Gateway health\n✓ Mock Phone OTP\n✓ STOP / cleanup"; default: return "Ready for deterministic fixture validation\nURL, title and DOM checks remain enabled." } }
}
