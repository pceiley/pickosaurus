import AppKit
@testable import Pickosaurus

@main
struct WindowBehaviorChecks {
    @MainActor
    static func main() async {
        let suite = "Pickosaurus.WindowChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = RuleEditorWindowSize(defaults: defaults)
        let largeScreen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        assert(storage.restoredSize(in: largeScreen) == NSSize(width: 620, height: 680))
        storage.save(NSSize(width: 850, height: 740))
        let reopened = RuleEditorWindowSize(defaults: UserDefaults(suiteName: suite)!)
        assert(reopened.restoredSize(in: largeScreen) == NSSize(width: 850, height: 740))
        assert(reopened.restoredSize(in: NSRect(x: 0, y: 0, width: 640, height: 480)) == NSSize(width: 592, height: 400))
        // Adapting to another screen does not replace the saved preference.
        assert(reopened.restoredSize(in: largeScreen) == NSSize(width: 850, height: 740))
        storage.save(NSSize(width: 300, height: 200))
        storage.save(NSSize(width: CGFloat.infinity, height: 700))
        assert(storage.restoredSize(in: largeScreen) == NSSize(width: 850, height: 740))
        storage.save(RuleEditorWindowSize.minimum)
        assert(reopened.restoredSize(in: largeScreen) == RuleEditorWindowSize.minimum)
        print("PASS: editor sizes persist across storage instances, fit smaller screens, and reject invalid dimensions")

        _ = NSApplication.shared
        var policies: [NSApplication.ActivationPolicy] = []
        let presentation = AppWindowPresentation(setPolicy: { policies.append($0) })
        // Offscreen windows and an injected policy setter leave the actual Dock untouched.
        let first = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        let second = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        let untracked = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
        presentation.register(first)
        assert(policies.last == .regular)
        presentation.register(second)
        presentation.register(second)
        presentation.unregister(first)
        assert(policies.last == .regular)
        let count = policies.count
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: untracked)
        assert(policies.count == count)
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: second)
        assert(policies.last == .accessory)
        presentation.unregister(second)
        assert(policies.last == .accessory)
        presentation.register(first)
        assert(policies.last == .regular)
        presentation.unregister(first)
        assert(policies.last == .accessory)
        print("PASS: Dock policy handles multiple windows, repeated shows, close/hide, reopening, and unrelated popovers")

        var foregroundWindows: [NSWindow] = []
        let foreground = AppWindowPresentation(setPolicy: { _ in }, bringForward: { foregroundWindows.append($0) })
        foreground.show(first)
        assert(foregroundWindows.isEmpty, "Focus must wait until the menu action has finished")
        await drainPresentationQueue()
        assert(foregroundWindows == [first])
        foreground.show(second)
        foreground.hide(second)
        await drainPresentationQueue()
        assert(foregroundWindows == [first], "A dismissed window must not reappear")
        foreground.show(second)
        await drainPresentationQueue()
        assert(foregroundWindows == [first, second])
        foreground.show(first)
        NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: first)
        await drainPresentationQueue()
        assert(foregroundWindows == [first, second], "A closed window must not take focus")
        foreground.unregister(second)
        print("PASS: foreground presentation waits for menu dismissal, supports reopening and cancels on hide/close")
    }

    @MainActor
    private static func drainPresentationQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
