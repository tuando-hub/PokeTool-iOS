import UIKit

final class SectionHeader: UILabel {
    init(_ text: String) { super.init(frame: .zero); self.text = text.uppercased(); font = .preferredFont(forTextStyle: .caption1); textColor = AppTheme.muted; adjustsFontForContentSizeCategory = true }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
}

final class StatusBadge: UILabel {
    init(_ title: String, color: UIColor) { super.init(frame: .zero); text = "  \(title.uppercased())  "; textColor = color; backgroundColor = color.withAlphaComponent(0.16); font = .preferredFont(forTextStyle: .caption1); layer.cornerRadius = 8; clipsToBounds = true; setContentHuggingPriority(.required, for: .horizontal) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
}

final class MetricTile: UIView {
    init(label: String, value: String, color: UIColor = .label) { super.init(frame: .zero); backgroundColor = AppTheme.card; layer.cornerRadius = 12; layer.borderWidth = 1; layer.borderColor = AppTheme.border.cgColor; let l = UILabel(); l.text = label.uppercased(); l.textColor = AppTheme.muted; l.font = .preferredFont(forTextStyle: .caption2); let v = UILabel(); v.text = value; v.textColor = color; v.font = .preferredFont(forTextStyle: .headline); let s = UIStackView(arrangedSubviews: [l, v]); s.axis = .vertical; s.spacing = 4; s.translatesAutoresizingMaskIntoConstraints = false; addSubview(s); NSLayoutConstraint.activate([s.topAnchor.constraint(equalTo: topAnchor, constant: 10), s.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10), s.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10), s.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)]) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
}

final class CompactRow: UIControl {
    init(title: String, detail: String, icon: String, tint: UIColor = AppTheme.accent) { super.init(frame: .zero); accessibilityLabel = title; backgroundColor = AppTheme.card; layer.cornerRadius = 12; let image = UIImageView(image: UIImage(systemName: icon)); image.tintColor = tint; let t = UILabel(); t.text = title; t.font = .preferredFont(forTextStyle: .callout); let d = UILabel(); d.text = detail; d.textColor = AppTheme.muted; d.font = .preferredFont(forTextStyle: .caption1); let s = UIStackView(arrangedSubviews: [image, t, d, UIImageView(image: UIImage(systemName: "chevron.right"))]); s.axis = .horizontal; s.spacing = 10; s.alignment = .center; s.translatesAutoresizingMaskIntoConstraints = false; addSubview(s); NSLayoutConstraint.activate([s.topAnchor.constraint(equalTo: topAnchor, constant: 12), s.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), s.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12), s.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)]) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
}
