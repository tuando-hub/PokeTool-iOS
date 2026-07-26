import Foundation
import WebKit

final class WebViewAutomationService: NSObject, BrowserAutomating {
    @MainActor
    lazy var visibleWebView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }()

    private var navigationCompletion: ((Result<Void, Error>) -> Void)?

    func load(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            navigationCompletion = completion
            visibleWebView.load(URLRequest(url: url))
        }
    }

    func evaluate(script: String, completion: @escaping (Result<Any?, Error>) -> Void) {
        Task { @MainActor in
            do {
                let value = try await visibleWebView.evaluateJavaScript(script)
                completion(.success(value))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func clear(completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            WKWebsiteDataStore.default().removeData(
                ofTypes: dataTypes,
                modifiedSince: .distantPast
            ) {
                completion(.success(()))
            }
        }
    }

    func stop() {
        Task { @MainActor in
            visibleWebView.stopLoading()
            navigationCompletion = nil
        }
    }
}

extension WebViewAutomationService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationCompletion?(.success(()))
        navigationCompletion = nil
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationCompletion?(.failure(error))
        navigationCompletion = nil
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationCompletion?(.failure(error))
        navigationCompletion = nil
    }
}

