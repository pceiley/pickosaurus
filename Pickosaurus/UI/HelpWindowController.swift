import AppKit

/// Bundled text displayed by AppKit, with no web view or navigation engine.
@MainActor
final class HelpWindowController: NSObject, NSWindowDelegate {
    static let faq = HelpWindowController(resourceName: "faq", title: "Pickosaurus — FAQ")
    static let privacy = HelpWindowController(resourceName: "privacy", title: "Pickosaurus — Privacy Policy")
    static let ruleMatching = HelpWindowController(resourceName: "rule-matching-help", title: "Pickosaurus — Matching Help")

    private var window: NSWindow?
    private let resourceName: String
    private let title: String

    private init(resourceName: String, title: String) {
        self.resourceName = resourceName
        self.title = title
        super.init()
    }

    func show() {
        if window == nil {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 660, height: 640))
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder
            let textView = HelpText.makeView(size: scrollView.contentSize)
            let text = Bundle.main.url(forResource: resourceName, withExtension: "txt")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
                ?? "# Help not found\n\nPlease consult the Pickosaurus README."
            textView.textStorage?.setAttributedString(HelpText.render(text))
            scrollView.documentView = textView

            let panel = NSPanel(contentRect: scrollView.frame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            panel.title = title
            panel.worksWhenModal = true
            panel.hidesOnDeactivate = false
            panel.contentView = scrollView
            panel.minSize = NSSize(width: 460, height: 480)
            panel.center()
            panel.delegate = self
            panel.isReleasedWhenClosed = false
            window = panel
        }
        AppWindowPresentation.shared.show(window)
    }
}

@MainActor
enum HelpText {
    static func makeView(size: NSSize) -> NSTextView {
        let view = NSTextView(frame: NSRect(origin: .zero, size: size))
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.isAutomaticLinkDetectionEnabled = false
        view.usesFindBar = true
        view.isIncrementalSearchingEnabled = true
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainerInset = NSSize(width: 24, height: 24)
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: size.width - 48, height: CGFloat.greatestFiniteMagnitude)
        view.setAccessibilityLabel("Help text")
        return view
    }

    /// Only heading markers are styled. URLs and regex examples remain literal, copyable text.
    static func render(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for paragraph in text.components(separatedBy: "\n\n") {
            let marker = ["### ", "## ", "# "].first { paragraph.hasPrefix($0) }
            let content = marker.map { String(paragraph.dropFirst($0.count)) } ?? paragraph
            let style = NSMutableParagraphStyle()
            style.paragraphSpacing = marker == nil ? 12 : 8
            style.paragraphSpacingBefore = marker == nil ? 0 : 12
            style.lineSpacing = 3
            let size: CGFloat = marker == "# " ? 26 : marker == "## " ? 19 : marker == "### " ? 15 : 14
            result.append(NSAttributedString(string: content + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: marker == nil ? .regular : .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]))
        }
        return result
    }
}
