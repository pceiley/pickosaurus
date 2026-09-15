import AppKit
import SwiftUI

enum ShortcutRecordingAction: Equatable {
    case assign(String?)
    case cancel
    case ignore

    static func forEvent(_ event: NSEvent) -> Self {
        guard event.type == .keyDown, !event.isARepeat else { return .ignore }
        guard event.modifierFlags.intersection([.command, .control, .option, .function]).isEmpty else { return .ignore }
        if event.keyCode == 53 { return .cancel }
        if event.keyCode == 51 || event.keyCode == 117 { return .assign(nil) }
        return PickerShortcuts.key(from: event).map { .assign($0) } ?? .ignore
    }
}

/// Recording belongs to the popover's first responder, never a global key monitor.
struct ShortcutRecorder<Label: View>: View {
    let name: String
    let shortcut: String?
    let onChange: (String?) -> Void
    @ViewBuilder let label: () -> Label
    @State private var recording = false

    var body: some View {
        Button { recording = true } label: {
            HStack(spacing: 10) {
                label()
                Spacer(minLength: 12)
                Text(shortcut?.uppercased() ?? "None")
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .frame(minWidth: 45)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set picker shortcut for \(name)")
        .accessibilityValue(shortcut?.uppercased() ?? "Disabled")
        .popover(isPresented: $recording) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shortcut for \(name)").font(.headline)
                Text("Press a letter or number.")
                Text("Escape cancels. Delete removes the shortcut.")
                    .font(.caption).foregroundStyle(.secondary)
                ShortcutKeyCapture { action in
                    switch action {
                    case .assign(let key): recording = false; onChange(key)
                    case .cancel: recording = false
                    case .ignore: break
                    }
                }.frame(width: 1, height: 1)
                HStack {
                    Button("Disable Shortcut") { recording = false; onChange(nil) }
                    Spacer()
                    Button("Cancel") { recording = false }
                }
            }
            .padding(16).frame(width: 300)
        }
    }
}

private struct ShortcutKeyCapture: NSViewRepresentable {
    var onAction: (ShortcutRecordingAction) -> Void

    func makeNSView(context: Context) -> ShortcutRecordingView {
        let view = ShortcutRecordingView()
        view.onAction = onAction
        return view
    }

    func updateNSView(_ view: ShortcutRecordingView, context: Context) { view.onAction = onAction }
}

final class ShortcutRecordingView: NSView {
    var onAction: (ShortcutRecordingAction) -> Void = { _ in }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Wait until SwiftUI has attached the popover's controls before taking focus.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { window?.selectNextKeyView(nil); return }
        onAction(ShortcutRecordingAction.forEvent(event))
    }
}
