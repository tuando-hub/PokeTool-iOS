import UIKit

enum AppTheme {
    static let background = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.035, green: 0.047, blue: 0.075, alpha: 1) : .systemGroupedBackground }
    static let card = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(red: 0.075, green: 0.095, blue: 0.14, alpha: 1) : .secondarySystemGroupedBackground }
    static let border = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.08) : UIColor.black.withAlphaComponent(0.08) }
    static let accent = UIColor.systemBlue
    static let success = UIColor.systemGreen
    static let warning = UIColor.systemOrange
    static let danger = UIColor.systemRed
    static let muted = UIColor.secondaryLabel
    static func cardView() -> UIView { let v = UIView(); v.backgroundColor = card; v.layer.cornerRadius = 16; v.layer.borderWidth = 1; v.layer.borderColor = border.cgColor; return v }
}
