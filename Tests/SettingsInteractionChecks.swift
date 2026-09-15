import AppKit
import ServiceManagement
@testable import Pickosaurus

@main
struct SettingsInteractionChecks {
    @MainActor
    static func main() async {
        func key(_ value: String, code: UInt16 = 3, modifiers: NSEvent.ModifierFlags = [], repeated: Bool = false) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: 0, context: nil, characters: value, charactersIgnoringModifiers: value,
                isARepeat: repeated, keyCode: code)!
        }
        precondition(ShortcutRecordingAction.forEvent(key("f")) == .assign("f"))
        precondition(ShortcutRecordingAction.forEvent(key("F", modifiers: [.shift])) == .assign("f"))
        precondition(ShortcutRecordingAction.forEvent(key("F", modifiers: [.capsLock])) == .assign("f"))
        precondition(ShortcutRecordingAction.forEvent(key("7", code: 26)) == .assign("7"))
        precondition(ShortcutRecordingAction.forEvent(key("\u{1b}", code: 53)) == .cancel)
        precondition(ShortcutRecordingAction.forEvent(key("\u{7f}", code: 51)) == .assign(nil))
        precondition(ShortcutRecordingAction.forEvent(key("\u{f728}", code: 117)) == .assign(nil))
        for flags: NSEvent.ModifierFlags in [.command, .control, .option, .function] {
            precondition(ShortcutRecordingAction.forEvent(key("f", modifiers: flags)) == .ignore)
        }
        precondition(ShortcutRecordingAction.forEvent(key("f", repeated: true)) == .ignore)
        precondition(ShortcutRecordingAction.forEvent(key("é")) == .ignore)
        _ = NSApplication.shared
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        let recorder = ShortcutRecordingView()
        var recorded: ShortcutRecordingAction?
        recorder.onAction = { recorded = $0 }
        window.contentView = recorder
        precondition(window.makeFirstResponder(recorder))
        recorder.keyDown(with: key("f"))
        precondition(recorded == .assign("f"))
        recorder.keyDown(with: key("\u{7f}", code: 51))
        precondition(recorded == .assign(nil))
        window.contentView = nil
        print("PASS: direct shortcut input normalizes keys, rejects combinations/repeats, cancels and disables through the focused recorder")

        let example = #"(?i)^https?://([a-z0-9-]+\.)*example\.com(/|[?#]|$)"#
        let help = HelpText.render("# Matching help\n\n## Regex\n\n" + example + "\n\nhttps://example.com/?a=1&b=2")
        precondition(help.string.contains(example) && help.string.contains("https://example.com/?a=1&b=2"))
        precondition(!help.string.hasPrefix("#"))
        let helpView = HelpText.makeView(size: NSSize(width: 600, height: 500))
        precondition(!helpView.isEditable && helpView.isSelectable && helpView.usesFindBar)
        precondition(!helpView.isAutomaticLinkDetectionEnabled && !helpView.isHorizontallyResizable)
        helpView.textStorage?.setAttributedString(help)
        precondition(helpView.string == help.string)
        print("PASS: native help keeps regex/URL examples literal and copyable, supports Find, and never auto-links")

        let debugID = "com.pickosaurus.debug"
        precondition(DefaultBrowserService.isDefaultBrowser(bundleIdentifier: debugID, handler: { _ in debugID }))
        precondition(!DefaultBrowserService.isDefaultBrowser(bundleIdentifier: debugID, handler: { _ in "com.pickosaurus.app" }))
        precondition(!DefaultBrowserService.isDefaultBrowser(bundleIdentifier: debugID, handler: { $0 == "http" ? debugID : "com.apple.Safari" }))
        precondition(!DefaultBrowserService.isDefaultBrowser(bundleIdentifier: nil, handler: { _ in nil }))
        var requests: [String] = []
        let appURL = URL(fileURLWithPath: "/Applications/Pickosaurus Debug.app")
        do {
            try await DefaultBrowserService.setAsDefaultBrowser(applicationURL: appURL) { url, scheme in
                precondition(url == appURL)
                requests.append(scheme)
            }
        } catch { preconditionFailure("Fixture must succeed") }
        precondition(requests == ["http", "https"])
        requests = []
        do {
            try await DefaultBrowserService.setAsDefaultBrowser(applicationURL: appURL) { _, scheme in
                requests.append(scheme)
                throw NSError(domain: NSOSStatusErrorDomain, code: -128)
            }
            preconditionFailure("Cancellation was swallowed")
        } catch {}
        precondition(requests == ["http"])
        print("PASS: default-browser status checks both schemes by identity; requests stop on cancellation, with no system defaults changed by tests")

        var systemStatus: SMAppService.Status = .notRegistered
        var registrations = 0
        var removals = 0
        let login = LoginItemController(readStatus: { systemStatus }, register: {
            registrations += 1
            systemStatus = .enabled
        }, unregister: {
            removals += 1
            systemStatus = .notRegistered
        })
        precondition(!login.isRequested && registrations == 0 && removals == 0)
        await login.setEnabled(true)
        precondition(login.isRequested && login.status == .enabled && registrations == 1)
        await login.setEnabled(true)
        precondition(registrations == 1)
        systemStatus = .requiresApproval
        login.refresh()
        precondition(login.isRequested)
        await login.setEnabled(true)
        precondition(registrations == 1)
        await login.setEnabled(false)
        precondition(!login.isRequested && removals == 1)
        await login.setEnabled(false)
        precondition(removals == 1)
        systemStatus = .enabled
        login.refresh()
        precondition(login.isRequested)
        print("PASS: login items are opt-in, reflect macOS approval/external changes, and avoid duplicate registration/removal")

        enum Failure: Error { case denied }
        let denied = LoginItemController(readStatus: { .notRegistered }, register: { throw Failure.denied }, unregister: {})
        await denied.setEnabled(true)
        precondition(!denied.isRequested && !denied.isChanging && denied.errorMessage != nil)
        let retained = LoginItemController(readStatus: { .enabled }, register: {}, unregister: { throw Failure.denied })
        await retained.setEnabled(false)
        precondition(retained.isRequested && !retained.isChanging && retained.errorMessage != nil)
        print("PASS: login-item failures expose an error and retain the actual macOS state; tests never register this Mac for login")
    }
}
