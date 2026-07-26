import UIKit
import WebKit

final class BrowserViewController: UIViewController, UITextFieldDelegate {
    private let viewModel: BrowserViewModel
    private weak var browserWebView: WKWebView?
    private let address = UITextField()
    private let status = UILabel()

    init(viewModel: BrowserViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Browser Engine"
        view.backgroundColor = .systemBackground
        configureHarness()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let webView = browserWebView else { return }
        viewModel.updateViewport(
            size: webView.bounds.size, safeAreaInsets: webView.safeAreaInsets,
            scale: view.window?.screen.scale ?? UIScreen.main.scale
        )
        updateStatus()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        run { try await self.viewModel.load(textField.text ?? "") }
        return true
    }

    private func configureHarness() {
        address.placeholder = "https://example.com"
        address.borderStyle = .roundedRect
        address.autocapitalizationType = .none
        address.autocorrectionType = .no
        address.keyboardType = .URL
        address.returnKeyType = .go
        address.delegate = self

        let controls = UIStackView(arrangedSubviews: [
            button("Back", #selector(back)), button("Forward", #selector(forward)),
            button("Reload", #selector(reload)), button("Stop", #selector(stop))
        ])
        controls.axis = .horizontal
        controls.distribution = .fillEqually

        status.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        status.numberOfLines = 2
        status.textColor = .secondaryLabel

        let webView: WKWebView
        do { webView = try viewModel.webView() }
        catch { show(error); return }
        browserWebView = webView

        let stack = UIStackView(arrangedSubviews: [address, controls, status, webView])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            address.heightAnchor.constraint(equalToConstant: 38),
            controls.heightAnchor.constraint(equalToConstant: 34),
            status.heightAnchor.constraint(equalToConstant: 34)
        ])

        #if DEBUG
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Shot", style: .plain, target: self, action: #selector(screenshot)),
            UIBarButtonItem(title: "Debug", style: .plain, target: self, action: #selector(debugPrompt))
        ]
        #endif
        updateStatus()
    }

    private func button(_ title: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func back() { do { try viewModel.back(); updateStatus() } catch { show(error) } }
    @objc private func forward() { do { try viewModel.forward(); updateStatus() } catch { show(error) } }
    @objc private func stop() { do { try viewModel.stop(); updateStatus() } catch { show(error) } }
    @objc private func reload() { run { try await self.viewModel.reload() } }

    #if DEBUG
    @objc private func screenshot() {
        run {
            let result = try await self.viewModel.screenshot()
            self.status.text = "Screenshot: \(result.fileURL.lastPathComponent)"
        }
    }

    @objc private func debugPrompt() {
        let alert = UIAlertController(title: "Debug JavaScript / CSS", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "JavaScript; prefix CSS with css:" }
        alert.addAction(UIAlertAction(title: "Run", style: .default) { [weak self, weak alert] _ in
            guard let self, let input = alert?.textFields?.first?.text else { return }
            self.run {
                if input.hasPrefix("css:") {
                    let exists = try await self.viewModel.selectorExists(String(input.dropFirst(4)))
                    self.status.text = "Selector exists: \(exists)"
                } else {
                    self.status.text = "Result: \(try await self.viewModel.evaluate(input))"
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    #endif

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in do { try await work(); updateStatus() } catch { show(error) } }
    }

    private func updateStatus() {
        guard let snapshot = try? viewModel.snapshot() else { return }
        address.text = snapshot.navigation.currentURL?.absoluteString ?? address.text
        status.text = "\(snapshot.state.rawValue)  \(Int(snapshot.navigation.estimatedProgress * 100))%\n\(snapshot.navigation.title ?? "")"
    }

    private func show(_ error: Error) {
        status.text = error.localizedDescription
        status.textColor = .systemRed
    }
}
