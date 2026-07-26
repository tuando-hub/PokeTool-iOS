import UIKit
import WebKit

final class BrowserViewController: UIViewController {
    private let viewModel: BrowserViewModel
    private weak var browserWebView: WKWebView?

    init(viewModel: BrowserViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Storyboard initialization is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Browser"
        view.backgroundColor = .systemBackground

        let webView: WKWebView
        do {
            webView = try viewModel.webView()
        } catch {
            showBrowserError(error)
            return
        }
        browserWebView = webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let browserWebView else { return }
        viewModel.updateViewport(
            size: browserWebView.bounds.size,
            safeAreaInsets: browserWebView.safeAreaInsets,
            scale: view.window?.screen.scale ?? UIScreen.main.scale
        )
    }

    private func showBrowserError(_ error: Error) {
        let label = UILabel()
        label.text = error.localizedDescription
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }
}
