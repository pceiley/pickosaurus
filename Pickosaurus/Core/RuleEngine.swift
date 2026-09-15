import Foundation

enum RoutingDecision {
    case rule(RoutingRule)
    case defaultTarget(RouteTarget)
    case picker
}

struct RuleEngine {
    /// Shared by live routing and the rule tester so fallback behavior stays identical.
    func decision(for context: RoutingContext, settings: AppSettings, hasEnabledDefault: @autoclosure () -> Bool) -> RoutingDecision {
        if settings.alwaysShowPicker { return .picker }
        if let rule = matchingRule(for: context, in: settings) {
            return .rule(rule)
        }
        if settings.fallbackMode == .picker || !hasEnabledDefault() || !canOpen(context.url, target: settings.defaultTarget, settings: settings) {
            return .picker
        }
        return .defaultTarget(settings.defaultTarget)
    }

    func matchingRule(for context: RoutingContext, in settings: AppSettings) -> RoutingRule? {
        guard !settings.alwaysShowPicker else { return nil }
        return settings.rules
            .sorted { $0.priority < $1.priority }
            .first {
                $0.enabled && settings.isTargetEnabled($0.target)
                    && canOpen(context.url, target: $0.target, settings: settings)
                    && $0.matches(url: context.url, sourceApp: context.sourceApp)
            }
    }

    private func canOpen(_ url: URL, target: RouteTarget, settings: AppSettings) -> Bool {
        guard target.applicationBundleIdentifier != nil else { return true }
        guard let app = settings.application(for: target) else { return false }
        return (try? app.urlToOpen(url)) != nil
    }

}
