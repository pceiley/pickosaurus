import Foundation
@testable import Pickosaurus

@main
struct RuleTesterChecks {
    @MainActor
    static func main() throws {
        for input in ["", "example.com", "/work/", "https://", "https://exa mple.com", "https://example.com/a b", "https://example.com/%ZZ", "file:///tmp/test", "javascript:alert(1)"] {
            assert(RuleTester.parseURL(input) == nil, "Unexpected valid URL: \(input)")
        }
        for input in ["https://example.com", "  https://example.com/work/?q=hello%20world#tab\n", "http://localhost:8080/a", "https://[::1]/", "HTTPS://EXAMPLE.COM"] {
            assert(RuleTester.parseURL(input) != nil, "Unexpected invalid URL: \(input)")
        }
        print("PASS: tester validates absolute HTTP(S) URLs and preserves encoded URLs")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configURL = folder.appendingPathComponent("config.json")
        let work = BrowserDestination(browser: .chrome)
        let personal = BrowserDestination(browser: .firefox)
        let zen = BrowserDestination(browser: .zen)
        let workTarget = RouteTarget(browser: .chrome)
        let personalTarget = personal.target
        let specific = RoutingRule(name: "Company", priority: 0, matchers: [
            RuleMatcher(kind: .hostEquals, value: "example.com"),
            RuleMatcher(kind: .pathPrefix, value: "/work/"),
            RuleMatcher(kind: .urlRegex, value: "[?&]private=1", isNegated: true)
        ], matchMode: .all, target: workTarget)
        let later = RoutingRule(name: "Personal", priority: 1,
            matchers: [RuleMatcher(kind: .hostEquals, value: "example.com")], target: personalTarget)
        let settings = AppSettings(fallbackMode: .silent, defaultTarget: personalTarget, rules: [later, specific])
        try JSONEncoder().encode(settings).write(to: configURL)
        let store = SettingsStore(configURL: configURL, discoverBrowsers: { [work, personal, zen] })
        store.reloadBrowsers()
        let url = RuleTester.parseURL("https://example.com/work/item")!
        let unrelated = RuleTester.parseURL("https://unrelated.test/")!
        let before = try Data(contentsOf: configURL)
        let result = RuleTester.test(url: url, store: store)
        assert(result.matchedRuleID == specific.id && result.destination == work && result.target == workTarget)
        let after = try Data(contentsOf: configURL)
        assert(after == before)
        assert(store.settings.rules == settings.rules)
        let privateURL = RuleTester.parseURL("https://example.com/work/item?private=1")!
        assert(RuleTester.test(url: privateURL, store: store).matchedRuleID == later.id)
        print("PASS: tester uses priority, AND, NOT, path and regex without changing saved settings")

        try store.setRuleEnabled(false, id: specific.id)
        assert(RuleTester.test(url: url, store: store).destination == personal)
        try store.setRuleEnabled(true, id: specific.id)
        try store.setBrowserEnabled(false, for: work)
        assert(RuleTester.test(url: url, store: store).matchedRuleID == later.id)
        let fallback = RuleTester.test(url: unrelated, store: store)
        assert(fallback.destination == personal && fallback.matchedRuleID == nil)
        try store.updateSettings { $0.fallbackMode = .picker }
        let picker = RuleTester.test(url: unrelated, store: store)
        assert(picker.title == "Link picker would open" && picker.target == nil)
        assert(RuleTester.test(url: url, store: store).matchedRuleID == later.id)
        try store.setBrowserEnabled(false, for: personal)
        try store.setBrowserEnabled(false, for: zen)
        let empty = RuleTester.test(url: url, store: store)
        assert(empty.title == "No enabled destinations" && empty.isWarning && empty.destination == nil)
        print("PASS: disabled rules/browsers, menu bar fallback, picker fallback and all-disabled state match live routing")

        try store.setBrowserEnabled(true, for: personal)
        var missing = specific
        missing.target = RouteTarget(browser: .edge)
        try store.updateRule(missing)
        let unavailable = RuleTester.test(url: url, store: store)
        assert(unavailable.matchedRuleID == specific.id && unavailable.isWarning && unavailable.destination == nil)
        assert(unavailable.target == missing.target)
        try store.updateSettings { $0.rules = []; $0.fallbackMode = .silent; $0.defaultTarget = missing.target }
        assert(RuleTester.test(url: unrelated, store: store).title == "Link picker would open")
        print("PASS: missing matched browser reports failure; missing default opens picker")

    }
}
