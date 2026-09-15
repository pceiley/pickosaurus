import AppKit

enum PickerShortcuts {
    static let availableKeys = Array("abcdefghijklmnopqrstuvwxyz0123456789").map(String.init)
    static let defaults = Dictionary(uniqueKeysWithValues: BrowserKind.allCases.map {
        ($0.rawValue, String($0.rawValue.prefix(1)))
    })

    static func normalized(_ value: String) -> String? {
        let key = value.lowercased()
        return availableKeys.contains(key) ? key : nil
    }

    static func key(from event: NSEvent) -> String? {
        guard event.type == .keyDown, !event.isARepeat,
              event.modifierFlags.intersection([.command, .control, .option, .function]).isEmpty,
              let characters = event.characters else { return nil }
        return normalized(characters)
    }

    static func isCopyEvent(_ event: NSEvent) -> Bool {
        event.type == .keyDown && !event.isARepeat
            && event.charactersIgnoringModifiers?.lowercased() == "c"
            && event.modifierFlags.intersection([.command, .control, .option, .shift, .function]) == [.command]
    }

    /// Ambiguous assignments in a manually edited config never launch a browser.
    static func browser(for key: String, settings: AppSettings) -> BrowserKind? {
        guard let key = normalized(key) else { return nil }
        let matches = BrowserKind.allCases.filter {
            settings.browserShortcuts[$0.rawValue].flatMap(normalized) == key
        }
        guard !settings.applications.contains(where: { $0.shortcut.flatMap(normalized) == key }) else { return nil }
        return matches.count == 1 ? matches.first : nil
    }

    static func application(for key: String, settings: AppSettings) -> LinkApplication? {
        guard let key = normalized(key),
              !BrowserKind.allCases.contains(where: { settings.browserShortcuts[$0.rawValue].flatMap(normalized) == key }) else { return nil }
        let matches = settings.applications.filter { $0.shortcut.flatMap(normalized) == key }
        return matches.count == 1 ? matches.first : nil
    }

    static func target(for key: String, settings: AppSettings, browsers: [BrowserDestination]) -> RouteTarget? {
        if let browser = browser(for: key, settings: settings) {
            return destination(for: browser, settings: settings, browsers: browsers)?.target
        }
        guard let app = application(for: key, settings: settings), app.enabled, app.applicationURL != nil else { return nil }
        return app.target
    }

    static func destination(for browser: BrowserKind, settings: AppSettings,
                            browsers: [BrowserDestination]) -> BrowserDestination? {
        guard settings.isBrowserEnabled(browser) else { return nil }
        return browsers.first { $0.browser == browser }
    }

}

enum PickerShortcutError: LocalizedError {
    case invalidKey
    case alreadyAssigned(BrowserKind)

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Choose a single letter (A–Z) or number (0–9)."
        case .alreadyAssigned(let browser): return "That key is already assigned to \(browser.displayName). Change its shortcut first."
        }
    }
}
