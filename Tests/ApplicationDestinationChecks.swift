import AppKit
import Foundation
@testable import Pickosaurus

@main
struct ApplicationDestinationChecks {
    @MainActor
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pickosaurus-apps-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func fixture(_ id: String, name: String) throws -> InstalledApplication {
            let url = root.appendingPathComponent(name + ".app")
            try FileManager.default.createDirectory(at: url.appendingPathComponent("Contents"), withIntermediateDirectories: true)
            let info = ["CFBundleIdentifier": id, "CFBundleName": name, "CFBundlePackageType": "APPL"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url.appendingPathComponent("Contents/Info.plist"))
            return InstalledApplication(url: url)!
        }
        let receiver = try fixture("test.pickosaurus.receiver.\(UUID().uuidString)", name: "Link Receiver")
        let other = try fixture("test.pickosaurus.other.\(UUID().uuidString)", name: "Other App")
        let config = root.appendingPathComponent("settings/config.json")
        let store = SettingsStore(configURL: config, discoverBrowsers: { [] })
        let browserTarget = RouteTarget(browser: .firefox)
        let decodedBrowser = try JSONDecoder().decode(RouteTarget.self, from: JSONEncoder().encode(browserTarget))
        precondition(decodedBrowser == browserTarget)
        let appTarget = RouteTarget(applicationBundleIdentifier: receiver.id)
        let data = try JSONEncoder().encode(appTarget)
        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(raw.keys.count == 1 && raw["applicationBundleIdentifier"] as? String == receiver.id)
        let decodedApp = try JSONDecoder().decode(RouteTarget.self, from: data)
        precondition(decodedApp == appTarget)
        print("PASS: browser targets round-trip; application targets round-trip without browser fields")

        try store.addApplication(receiver)
        try store.addApplication(receiver)
        try store.addApplication(other)
        precondition(store.settings.applications.count == 2)
        var app = store.settings.applications[0]
        precondition(app.applicationURL?.standardizedFileURL.path == receiver.url.standardizedFileURL.path && store.isAvailable(app.target), "Saved app should resolve by identity and path")
        app.shortcut = "M"
        try store.updateApplication(app)
        precondition(SettingsStore(configURL: config).settings.applications[0].shortcut == "m")
        precondition(PickerShortcuts.target(for: "m", settings: store.settings, browsers: []) == app.target)
        do { try store.setBrowserShortcut("m", for: .firefox); preconditionFailure("Browser stole app key") }
        catch ApplicationLaunchError.shortcutInUse(_) {}
        app.shortcut = "f"
        do { try store.updateApplication(app); preconditionFailure("App stole browser key") }
        catch PickerShortcutError.alreadyAssigned(.firefox) {}
        var second = store.settings.applications[1]
        second.shortcut = "m"
        do { try store.updateApplication(second); preconditionFailure("Duplicate app key accepted") }
        catch ApplicationLaunchError.shortcutInUse(_) {}
        app = store.settings.applications[0]
        var wrongPath = app
        wrongPath.path = other.url.path
        precondition(wrongPath.applicationURL == nil)
        precondition(!LinkApplication.isAllowedDestination("com.pickosaurus.debug"))
        precondition(!LinkApplication.isAllowedDestination("com.pickosaurus.app"))
        print("PASS: application identity, deduplication, persisted shortcuts and cross-browser/app key conflicts are enforced")

        let link = URL(string: "https://example.com/path?private=1#fragment")!
        let originalLink = try app.urlToOpen(link)
        precondition(originalLink == link)
        try store.updateSettings { $0.alwaysShowPicker = false }
        let rule = RoutingRule(name: "Use receiver", priority: 0, matchers: [RuleMatcher(kind: .hostEquals, value: "example.com")], target: app.target)
        try store.addRule(rule)
        let context = RoutingContext(url: link, sourceApp: nil)
        precondition(RuleEngine().matchingRule(for: context, in: store.settings)?.id == rule.id)
        let preview = RuleTester.test(url: link, store: store)
        precondition(preview.application?.id == app.id && preview.target == app.target && !preview.isWarning)
        try store.setFallbackDestination(app.target)
        precondition(store.hasEnabledDefaultDestination)
        app.enabled = false
        try store.updateApplication(app)
        precondition(!store.isAvailable(app.target) && !store.hasEnabledDefaultDestination)
        precondition(PickerShortcuts.target(for: "m", settings: store.settings, browsers: []) == nil)
        precondition(RuleEngine().matchingRule(for: context, in: store.settings) == nil)
        app.enabled = true
        try store.updateApplication(app)
        try store.updateSettings { $0.alwaysShowPicker = true }
        precondition(store.enabledApplications.count == 2)
        precondition(RuleEngine().matchingRule(for: context, in: store.settings) == nil)
        precondition(PickerShortcuts.target(for: "m", settings: store.settings, browsers: []) == app.target)
        try store.removeApplication(id: app.id)
        precondition(store.settings.rules.first?.target == app.target)
        precondition(!store.settings.isTargetEnabled(app.target))
        print("PASS: applications work in rules/tester/defaults and always-show picker; disabling/removal blocks dispatch without losing rules")

        let meeting = URL(string: "https://us02web.zoom.us/j/12345678901?pwd=a%2Bb%26c%3Dd")!
        let converted = ZoomMeetingLink.convert(meeting)!
        let components = URLComponents(url: converted, resolvingAgainstBaseURL: false)!
        precondition(components.scheme == "zoommtg" && components.host == "us02web.zoom.us" && components.path == "/join")
        precondition(components.queryItems?.first { $0.name == "confno" }?.value == "12345678901")
        precondition(components.queryItems?.first { $0.name == "pwd" }?.value == "a+b&c=d")
        precondition(components.percentEncodedQuery?.contains("%2B") == true)
        for value in ["https://zoom.us/j/123456789", "https://company.zoom.com/j/12345678901", "https://zoom.us/j/12345678901?omn=123&from=calendar"] {
            precondition(ZoomMeetingLink.convert(URL(string: value)!) != nil)
        }
        for value in ["https://evilzoom.us/j/12345678901", "https://zoom.us.evil.test/j/12345678901", "https://zoom.us@evil.test/j/12345678901", "https://user@zoom.us/j/12345678901", "https://zoom.us:444/j/12345678901", "https://zoom.us/my/personal", "https://zoom.us/meeting/register/12345678901", "https://zoom.us/j/123", "https://zoom.us/j/12345678901?tk=secret", "https://zoom.us/j/12345678901?pwd=a&pwd=b", "file:///j/12345678901", "zoommtg://zoom.us/join?confno=12345678901"] {
            precondition(ZoomMeetingLink.convert(URL(string: value)!) == nil, value)
        }
        var zoom = LinkApplication(id: "us.zoom.xos", name: "Zoom", path: "/missing/Zoom.app")
        let zoomRule = RoutingRule(name: "Zoom", priority: 0, matchers: [RuleMatcher(kind: .hostSuffix, value: "zoom.us")], target: zoom.target)
        let browserRule = RoutingRule(name: "Zoom web pages", priority: 1, matchers: zoomRule.matchers, target: browserTarget)
        var settings = AppSettings(fallbackMode: .silent, defaultTarget: zoom.target, rules: [zoomRule, browserRule], applications: [zoom])
        precondition(RuleEngine().matchingRule(for: RoutingContext(url: meeting, sourceApp: nil), in: settings)?.target == zoom.target)
        let web = RoutingContext(url: URL(string: "https://zoom.us/my/personal")!, sourceApp: nil)
        precondition(RuleEngine().matchingRule(for: web, in: settings)?.target == browserTarget)
        precondition(RuleConflictAnalyzer().conflicts(in: settings)[browserRule.id] == nil)
        settings.rules = []
        if case .picker = RuleEngine().decision(for: web, settings: settings, hasEnabledDefault: true) {} else { preconditionFailure("Unsupported Zoom fallback must show picker") }
        zoom.enabled = false
        settings.applications = [zoom]
        precondition(!settings.isTargetEnabled(zoom.target))
        print("PASS: Zoom invitations preserve meeting IDs/passcodes; spoofed hosts and web-only flows are rejected without shadowing browser rules")

        var tracker = ApplicationHandoffTracker()
        let now = Date()
        tracker.record(link, applicationID: receiver.id, now: now)
        precondition(tracker.wasReturned(link, sourceApp: receiver.id, now: now))
        precondition(!tracker.wasReturned(link, sourceApp: other.id, now: now))
        precondition(!tracker.wasReturned(link, sourceApp: nil, now: now))
        precondition(!tracker.wasReturned(link, sourceApp: receiver.id, now: now.addingTimeInterval(31)))
        print("PASS: returned links trigger loop protection only for the original destination and expire after 30 seconds")
    }

    static func tryDecode(_ object: [String: Any]) -> AppSettings {
        try! JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
