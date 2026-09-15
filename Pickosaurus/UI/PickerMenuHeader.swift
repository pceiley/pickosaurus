import AppKit

/// A quiet hostname footer; destination rows retain native menu behavior.
final class PickerMenuHeader: NSView {
    private let hostLabel = NSTextField(labelWithString: "Choose a destination")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 30))
        hostLabel.font = .systemFont(ofSize: 12, weight: .medium)
        hostLabel.textColor = .secondaryLabelColor
        hostLabel.alignment = .center
        hostLabel.lineBreakMode = .byTruncatingMiddle
        hostLabel.maximumNumberOfLines = 1
        hostLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostLabel)
        NSLayoutConstraint.activate([
            hostLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hostLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hostLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Choose a destination")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(host: String) {
        guard hostLabel.stringValue != host else { return }
        hostLabel.stringValue = host
        setAccessibilityLabel("Link host: \(host)")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
