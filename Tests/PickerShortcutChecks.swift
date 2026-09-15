import AppKit
import Foundation
@testable import Pickosaurus

@main
struct PickerShortcutChecks {
    @MainActor
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pickosaurus-shortcuts-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let config = folder.appendingPathComponent("config.json")
        let store = SettingsStore(configURL: config, discoverBrowsers: { [] })
        precondition(PickerShortcuts.browser(for: "F", settings: store.settings) == .firefox)
        precondition(Set(PickerShortcuts.defaults.values).count == BrowserKind.allCases.count)
        print("PASS: new settings receive unique browser shortcut defaults")

        try store.setBrowserShortcut("1", for: .firefox)
        precondition(SettingsStore(configURL: config).settings.browserShortcuts["firefox"] == "1")
        try store.setBrowserShortcut(nil, for: .chrome)
        try store.setBrowserShortcut("C", for: .firefox)
        precondition(store.settings.browserShortcuts["firefox"] == "c")
        precondition(SettingsStore(configURL: config).settings.browserShortcuts["chrome"] == nil)
        do {
            try store.setBrowserShortcut("c", for: .safari)
            preconditionFailure("Duplicate key accepted")
        } catch PickerShortcutError.alreadyAssigned(.firefox) {}
        for key in ["", "ff", " ", "é", "⌘", "\n"] {
            do {
                try store.setBrowserShortcut(key, for: .safari)
                preconditionFailure("Invalid key accepted")
            } catch PickerShortcutError.invalidKey {}
        }
        precondition(store.settings.browserShortcuts["safari"] == "s")
        for browser in BrowserKind.allCases { try store.setBrowserShortcut(nil, for: browser) }
        precondition(SettingsStore(configURL: config).settings.browserShortcuts.isEmpty)
        print("PASS: assignment, removal, case normalization and numeric keys persist; conflicts and invalid keys are rejected")

        let blocker = folder.appendingPathComponent("not-a-directory")
        try Data().write(to: blocker)
        let failing = SettingsStore(configURL: blocker.appendingPathComponent("config.json"))
        do {
            try failing.setBrowserShortcut("1", for: .firefox)
            preconditionFailure("Save unexpectedly succeeded")
        } catch {}
        precondition(failing.settings.browserShortcuts == PickerShortcuts.defaults)
        print("PASS: failed shortcut saves preserve the previous settings")

        let firefox = BrowserDestination(browser: .firefox)
        let chrome = BrowserDestination(browser: .chrome)
        var settings = AppSettings.default
        let browsers = [firefox, chrome]
        precondition(PickerShortcuts.target(for: "f", settings: settings, browsers: browsers) == firefox.target)
        settings.disabledBrowsers = [.firefox]
        precondition(PickerShortcuts.target(for: "f", settings: settings, browsers: browsers) == nil)
        precondition(PickerShortcuts.destination(for: .safari, settings: settings, browsers: browsers) == nil)
        settings.browserShortcuts["chrome"] = "F"
        precondition(PickerShortcuts.browser(for: "f", settings: settings) == nil)
        print("PASS: shortcuts select browsers; disabled, missing and ambiguous destinations never launch")

        func event(_ characters: String, modifiers: NSEvent.ModifierFlags = [], repeated: Bool = false) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                             timestamp: 0, windowNumber: 0, context: nil, characters: characters,
                             charactersIgnoringModifiers: characters, isARepeat: repeated, keyCode: 3)!
        }
        precondition(PickerShortcuts.key(from: event("f")) == "f")
        precondition(PickerShortcuts.key(from: event("F", modifiers: [.shift])) == "f")
        precondition(PickerShortcuts.key(from: event("F", modifiers: [.capsLock])) == "f")
        for modifier: NSEvent.ModifierFlags in [.command, .control, .option, .function] {
            precondition(PickerShortcuts.key(from: event("f", modifiers: modifier)) == nil)
        }
        precondition(PickerShortcuts.key(from: event("f", repeated: true)) == nil)
        precondition(PickerShortcuts.isCopyEvent(event("c", modifiers: [.command])))
        precondition(!PickerShortcuts.isCopyEvent(event("c")))
        precondition(!PickerShortcuts.isCopyEvent(event("c", modifiers: [.command], repeated: true)))
        for modifier: NSEvent.ModifierFlags in [.shift, .control, .option, .function] {
            precondition(!PickerShortcuts.isCopyEvent(event("c", modifiers: [.command, modifier])))
        }
        for key in ["\u{1b}", "\r", "\t", " ", "\u{f700}"] {
            precondition(PickerShortcuts.key(from: event(key)) == nil)
        }
        print("PASS: plain/capital keys work; command combinations, navigation keys and key repeats are ignored")
    }
}
