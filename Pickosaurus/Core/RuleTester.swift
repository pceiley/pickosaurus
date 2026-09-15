import Foundation

struct RuleTestResult {
    let title: String
    let detail: String
    var destination: BrowserDestination?
    var target: RouteTarget?
    var matchedRuleID: UUID?
    var isWarning = false
    var application: LinkApplication?


}

enum RuleTester {
    static func parseURL(_ input: String) -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value, encodingInvalidCharacters: false),
              WebURL.isAllowed(url) else { return nil }
        return url
    }

    /// A read-only preview: no discovery, persistence, picker, or browser launch.
    @MainActor
    static func test(url: URL, store: SettingsStore, sourceApp: String? = nil) -> RuleTestResult {
        if store.settings.alwaysShowPicker {
            return RuleTestResult(title: "Link picker would open", detail: "Always show picker is enabled. Routing rules and the silent fallback are paused.", isWarning: store.enabledBrowsers.isEmpty && store.enabledApplications.isEmpty)
        }
        let decision = RuleEngine().decision(
            for: RoutingContext(url: url, sourceApp: sourceApp),
            settings: store.settings,
            hasEnabledDefault: store.hasEnabledDefaultDestination
        )
        let target: RouteTarget
        let rule: RoutingRule?
        switch decision {
        case .rule(let matched):
            rule = matched
            target = matched.target
        case .defaultTarget(let fallback):
            rule = nil
            target = fallback
        case .picker:
            if store.enabledBrowsers.isEmpty && store.enabledApplications.isEmpty {
                return RuleTestResult(title: "No enabled destinations", detail: "No rule matched. The picker would ask you to enable a browser or application in Settings.", isWarning: true)
            }
            return RuleTestResult(title: "Link picker would open", detail: "No rule matched. Choose a browser or application in the picker.")
        }

        let reason = rule.map { "Matched rule: \($0.name)" } ?? "No rule matched. Uses your fallback destination."
        if target.applicationBundleIdentifier != nil {
            guard let app = store.settings.application(for: target), store.isAvailable(target) else {
                return RuleTestResult(title: "Destination unavailable", detail: "\(reason) Add or enable the application in Settings → Applications.", target: target, matchedRuleID: rule?.id, isWarning: true)
            }
            return RuleTestResult(title: "Would open in", detail: reason, target: target, matchedRuleID: rule?.id, application: app)
        }
        guard let destination = store.destination(for: target) else {
            return RuleTestResult(title: "Destination unavailable", detail: "\(reason) The saved browser was not found. Update the rule’s destination in Settings → Rules.", target: target, matchedRuleID: rule?.id, isWarning: true)
        }
        return RuleTestResult(title: "Would open in", detail: reason, destination: destination, target: target, matchedRuleID: rule?.id)
    }
}
