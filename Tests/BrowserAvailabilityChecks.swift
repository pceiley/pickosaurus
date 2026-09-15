import Foundation
@testable import Pickosaurus

@main
struct BrowserAvailabilityChecks {
    @MainActor
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let config = folder.appendingPathComponent("config.json")
        let chrome = BrowserDestination(browser: .chrome)
        let firefox = BrowserDestination(browser: .firefox)
        var discovered = [chrome, firefox]
        var discoveries = 0
        let store = SettingsStore(configURL: config, discoverBrowsers: { discoveries += 1; return discovered })
        precondition(store.settings.alwaysShowPicker && store.settings.fallbackMode == .picker)
        store.loadBrowsersIfNeeded()
        store.loadBrowsersIfNeeded()
        precondition(discoveries == 1 && store.browsers == discovered)
        let fallbackConfig = folder.appendingPathComponent("fallback.json")
        let fallbackStore = SettingsStore(configURL: fallbackConfig, discoverBrowsers: { [chrome, firefox] })
        fallbackStore.loadBrowsersIfNeeded()
        try fallbackStore.updateSettings { $0.alwaysShowPicker = false }
        let fallbackContext = RoutingContext(url: URL(string: "https://unmatched.example")!, sourceApp: nil)
        try fallbackStore.setFallbackDestination(firefox.target)
        precondition(fallbackStore.fallbackDestination == firefox.target)
        guard case .defaultTarget(let target) = RuleEngine().decision(for: fallbackContext, settings: fallbackStore.settings, hasEnabledDefault: fallbackStore.hasEnabledDefaultDestination), target == firefox.target else {
            fatalError("Choosing a browser must activate it as the fallback")
        }
        precondition(SettingsStore(configURL: fallbackConfig).fallbackDestination == firefox.target)
        try fallbackStore.setFallbackDestination(nil)
        precondition(fallbackStore.fallbackDestination == nil)
        precondition(SettingsStore(configURL: fallbackConfig).fallbackDestination == nil)
        guard case .picker = RuleEngine().decision(for: fallbackContext, settings: fallbackStore.settings, hasEnabledDefault: true) else {
            fatalError("Choosing the picker must stop automatic fallback launches")
        }
        print("PASS: the single fallback choice switches live routing between a destination and the picker and persists across restart")
        let context = RoutingContext(url: URL(string: "https://example.com/work")!, sourceApp: nil)
        let matcher = RuleMatcher(kind: .hostEquals, value: "example.com")
        let first = RoutingRule(name: "Chrome", priority: 0, matchers: [matcher], target: chrome.target)
        let second = RoutingRule(name: "Firefox", priority: 1, matchers: [matcher], target: firefox.target)
        try store.updateSettings {
            $0.rules = [first, second]
            $0.defaultTarget = chrome.target
            $0.fallbackMode = .silent
        }
        let engine = RuleEngine()
        guard case .picker = engine.decision(for: context, settings: store.settings, hasEnabledDefault: true) else { fatalError("New installs must always show picker") }
        precondition(engine.matchingRule(for: context, in: store.settings) == nil)
        precondition(SettingsStore(configURL: config).settings.alwaysShowPicker)
        try store.updateSettings { $0.alwaysShowPicker = false }
        precondition(engine.matchingRule(for: context, in: store.settings)?.id == first.id)
        precondition(!SettingsStore(configURL: config).settings.alwaysShowPicker)
        print("PASS: picker is the default; automatic rules run when enabled without any permission setup")

        try store.setBrowserEnabled(false, for: chrome)
        precondition(store.enabledBrowsers == [firefox])
        precondition(engine.matchingRule(for: context, in: store.settings)?.id == second.id)
        precondition(!store.hasEnabledDefaultDestination)
        let unrelated = RoutingContext(url: URL(string: "https://other.test")!, sourceApp: nil)
        guard case .picker = engine.decision(for: unrelated, settings: store.settings, hasEnabledDefault: store.hasEnabledDefaultDestination) else { fatalError("Disabled default must show picker") }
        precondition(store.settings.defaultTarget == chrome.target)
        discovered = [firefox]
        store.reloadBrowsers()
        discovered = [chrome, firefox]
        store.reloadBrowsers()
        let restarted = SettingsStore(configURL: config, discoverBrowsers: { discovered })
        restarted.reloadBrowsers()
        precondition(!restarted.isBrowserEnabled(chrome))
        precondition(restarted.settings.rules == [first, second])
        try restarted.setBrowserEnabled(false, for: firefox)
        precondition(restarted.enabledBrowsers.isEmpty && !restarted.hasEnabledDefaultDestination)
        precondition(engine.matchingRule(for: context, in: restarted.settings) == nil)
        try restarted.setBrowserEnabled(true, for: chrome)
        precondition(restarted.hasEnabledDefaultDestination)
        precondition(engine.matchingRule(for: context, in: restarted.settings)?.id == first.id)
        print("PASS: disabling, disappearance, refresh and restart preserve browser choices; missing defaults ask instead of silently switching browsers")

        // Safari is not in discovery, so its default S key must be reusable from the visible list.
        try restarted.setBrowserShortcut("s", for: .chrome)
        precondition(restarted.settings.browserShortcuts["chrome"] == "s")
        precondition(restarted.settings.browserShortcuts["safari"] == nil)
        precondition(PickerShortcuts.target(for: "s", settings: restarted.settings, browsers: restarted.browsers) == chrome.target)
        try restarted.setBrowserShortcut(nil, for: .chrome)
        precondition(SettingsStore(configURL: config).settings.browserShortcuts["chrome"] == nil)
        print("PASS: visible browsers can reuse absent browsers' keys and disable their shortcut entirely")

        let before = restarted.settings
        try FileManager.default.removeItem(at: config)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: false)
        do {
            try restarted.setBrowserEnabled(false, for: chrome)
            preconditionFailure("Expected save failure")
        } catch {}
        precondition(restarted.settings.disabledBrowsers == before.disabledBrowsers)
        precondition(restarted.settings.defaultTarget == before.defaultTarget)
        print("PASS: failed availability saves leave the active settings unchanged")
    }
}
