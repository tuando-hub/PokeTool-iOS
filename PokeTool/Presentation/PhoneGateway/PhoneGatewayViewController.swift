import UIKit

final class PhoneGatewayViewController: UIViewController {
    private let configuration = PhoneGatewayConfiguration()
    private let urlField = UITextField()
    private let keyField = UITextField()
    private let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Phone OTP Gateway"
        view.backgroundColor = .systemBackground
        urlField.placeholder = "HTTPS gateway URL"
        urlField.text = configuration.baseURL
        urlField.borderStyle = .roundedRect
        urlField.autocapitalizationType = .none
        keyField.placeholder = "API key"
        keyField.borderStyle = .roundedRect
        keyField.isSecureTextEntry = true
        status.numberOfLines = 0
        let save = UIButton(type: .system)
        save.setTitle("Save", for: .normal)
        save.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
        let test = UIButton(type: .system)
        test.setTitle("Test Connection", for: .normal)
        test.addAction(UIAction { [weak self] _ in self?.testConnection() }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [urlField, keyField, save, test, status])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    private func save() {
        configuration.baseURL = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try? configuration.setAPIKey(keyField.text ?? "")
        keyField.text = nil
        status.text = "Saved securely in Keychain."
    }

    private func testConnection() {
        Task { @MainActor in
            do {
                let provider = try configuration.makeProvider()
                status.text = try await provider.health() ? "Gateway healthy." : "Gateway unavailable."
            } catch {
                status.text = "Connection failed: (error.localizedDescription)"
            }
        }
    }
}
