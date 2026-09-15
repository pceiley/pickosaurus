import AppKit
import Foundation

enum BrowserKind: String, Codable, CaseIterable, Identifiable {
    case chrome
    case edge
    case brave
    case vivaldi
    case dia
    case firefox
    case zen
    case safari

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .edge: return "Edge"
        case .brave: return "Brave"
        case .vivaldi: return "Vivaldi"
        case .dia: return "Dia"
        case .firefox: return "Firefox"
        case .zen: return "Zen"
        case .safari: return "Safari"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .brave: return "com.brave.Browser"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .dia: return "company.thebrowser.dia"
        case .firefox: return "org.mozilla.firefox"
        case .zen: return "app.zen-browser.zen"
        case .safari: return "com.apple.Safari"
        }
    }

    /// Default install location, used as a fallback when bundle-ID lookup fails.
    private var defaultAppPath: String {
        switch self {
        case .chrome: return "/Applications/Google Chrome.app"
        case .edge: return "/Applications/Microsoft Edge.app"
        case .brave: return "/Applications/Brave Browser.app"
        case .vivaldi: return "/Applications/Vivaldi.app"
        case .dia: return "/Applications/Dia.app"
        case .firefox: return "/Applications/Firefox.app"
        case .zen: return "/Applications/Zen.app"
        case .safari: return "/Applications/Safari.app"
        }
    }

    /// Resolves the installed app URL by bundle identifier (any location), else the default path.
    var installedAppURL: URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }
        if FileManager.default.fileExists(atPath: defaultAppPath) {
            return URL(fileURLWithPath: defaultAppPath)
        }
        return nil
    }

    var isInstalled: Bool { installedAppURL != nil }

}

/// One installed browser; the browser chooses its own current/default profile.
struct BrowserDestination: Identifiable, Hashable {
    let browser: BrowserKind
    var id: String { browser.rawValue }
    var displayName: String { browser.displayName }
    var target: RouteTarget { RouteTarget(browser: browser) }
}

struct RouteTarget: Codable, Hashable {
    var browser: BrowserKind?
    var applicationBundleIdentifier: String?
    init(browser: BrowserKind) { self.browser = browser }
    init(applicationBundleIdentifier: String) { self.applicationBundleIdentifier = applicationBundleIdentifier }

    private enum CodingKeys: String, CodingKey {
        case browser, applicationBundleIdentifier
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try values.decodeIfPresent(String.self, forKey: .applicationBundleIdentifier) {
            guard !id.isEmpty, !values.contains(.browser) else {
                throw DecodingError.dataCorruptedError(forKey: .applicationBundleIdentifier, in: values, debugDescription: "Ambiguous application destination")
            }
            self.init(applicationBundleIdentifier: id)
        } else {
            self.init(browser: try values.decode(BrowserKind.self, forKey: .browser))
        }
    }
    var label: String {
        return applicationBundleIdentifier ?? browser?.displayName ?? "Unavailable destination"
    }
}

enum FallbackMode: String, Codable {
    case silent
    case picker
}

enum RuleMatcherKind: String, Codable, CaseIterable, Identifiable {
    case urlContains
    case hostEquals
    case hostSuffix
    case pathEquals
    case pathPrefix
    case pathContains
    case urlRegex
    case sourceApplication

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .urlContains: return "URL contains"
        case .hostEquals: return "Host equals"
        case .hostSuffix: return "Host suffix"
        case .pathEquals: return "Path equals"
        case .pathPrefix: return "Path starts with"
        case .pathContains: return "Path contains"
        case .urlRegex: return "URL regex"
        case .sourceApplication: return "Source application"
        }
    }
}

struct RuleMatcher: Codable, Hashable {
    var kind: RuleMatcherKind
    var value: String
    var isNegated: Bool
    var applicationName: String?

    init(kind: RuleMatcherKind, value: String, isNegated: Bool = false, applicationName: String? = nil) {
        self.kind = kind
        self.value = value
        self.isNegated = isNegated
        self.applicationName = applicationName
    }

    var normalizedValue: String {
        kind == .urlRegex ? value : value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var summary: String {
        "\(isNegated ? "NOT " : "")\(kind.displayName): \(kind == .sourceApplication ? (applicationName ?? normalizedValue) : normalizedValue)"
    }

    var isValid: Bool {
        validationMessage == nil
    }

    var validationMessage: String? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Enter a value." }
        switch kind {
        case .sourceApplication:
            if normalizedValue.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                return "Choose an application from the list."
            }
        case .hostSuffix:
            if normalizedValue.trimmingCharacters(in: CharacterSet(charactersIn: ".")).isEmpty {
                return "Enter a domain, such as company.com."
            }
        case .pathEquals, .pathPrefix:
            if !normalizedValue.hasPrefix("/") { return "Start the path with /, for example /work/." }
        case .urlRegex:
            if CompiledRuleRegex.expression(for: value) == nil { return "Invalid regular expression. See Matching help for examples." }
        default: break
        }
        return nil
    }

    func matches(url: URL, sourceApp: String?) -> Bool {
        guard isValid else { return false }
        let value = normalizedValue
        let matched: Bool

        switch kind {
        case .sourceApplication:
            // Unknown is not the same as a different app, including under NOT.
            guard let sourceApp, !sourceApp.isEmpty else { return false }
            matched = sourceApp.caseInsensitiveCompare(normalizedValue) == .orderedSame
        case .urlContains:
            matched = url.absoluteString.lowercased().contains(value.lowercased())
        case .hostEquals:
            matched = (url.host ?? "").lowercased() == value.lowercased()
        case .hostSuffix:
            let suffix = value.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
            matched = (url.host ?? "").lowercased().hasSuffix(suffix)
        case .pathEquals, .pathPrefix, .pathContains:
            let decoded = url.path(percentEncoded: false)
            let path = decoded.isEmpty ? "/" : decoded
            switch kind {
            case .pathEquals: matched = path == value
            case .pathPrefix: matched = path.hasPrefix(value)
            default: matched = path.contains(value)
            }
        case .urlRegex:
            // An invalid or interrupted expression must not become a match under NOT.
            guard let result = regexMatches(url.absoluteString) else { return false }
            matched = result
        }
        return isNegated ? !matched : matched
    }

    private func regexMatches(_ string: String) -> Bool? {
        guard let regex = CompiledRuleRegex.expression(for: value) else { return nil }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.05
        var matched = false
        var interrupted = false
        regex.enumerateMatches(in: string, options: .reportProgress, range: NSRange(string.startIndex..., in: string)) { result, flags, stop in
            if flags.contains(.internalError) || ProcessInfo.processInfo.systemUptime > deadline {
                interrupted = true
                stop.pointee = true
            } else if result != nil {
                matched = true
                stop.pointee = true
            }
        }
        return interrupted ? nil : matched
    }
}

enum RuleMatchMode: String, Codable, CaseIterable, Identifiable {
    case any
    case all

    var id: String { rawValue }
    var displayName: String { self == .any ? "Any (OR)" : "All (AND)" }
    var conjunction: String { self == .any ? "OR" : "AND" }
    var explanation: String {
        self == .any
            ? "The rule applies when any one of these conditions matches."
            : "The rule applies only when all of these conditions match the same link."
    }
}

struct RoutingRule: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var enabled: Bool
    var priority: Int
    var matchers: [RuleMatcher]
    var matchMode: RuleMatchMode
    var target: RouteTarget

    init(
        id: UUID = UUID(),
        name: String,
        enabled: Bool = true,
        priority: Int,
        matchers: [RuleMatcher],
        matchMode: RuleMatchMode = .any,
        target: RouteTarget
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.priority = priority
        self.matchers = matchers
        self.matchMode = matchMode
        self.target = target
    }

    func matches(url: URL, sourceApp: String?) -> Bool {
        guard !matchers.isEmpty else { return false }
        switch matchMode {
        case .any:
            return matchers.contains { $0.matches(url: url, sourceApp: sourceApp) }
        case .all:
            return matchers.allSatisfy { $0.matches(url: url, sourceApp: sourceApp) }
        }
    }
}

struct AppSettings: Codable {
    var alwaysShowPicker: Bool
    var fallbackMode: FallbackMode
    var defaultTarget: RouteTarget
    var rules: [RoutingRule]
    var disabledBrowsers: Set<BrowserKind>
    var browserShortcuts: [String: String]
    var applications: [LinkApplication]

    init(fallbackMode: FallbackMode, defaultTarget: RouteTarget, rules: [RoutingRule],
         disabledBrowsers: Set<BrowserKind> = [],
         browserShortcuts: [String: String] = PickerShortcuts.defaults,
         applications: [LinkApplication] = [], alwaysShowPicker: Bool = false) {
        self.alwaysShowPicker = alwaysShowPicker
        self.fallbackMode = fallbackMode
        self.defaultTarget = defaultTarget
        self.rules = rules
        self.disabledBrowsers = disabledBrowsers
        self.browserShortcuts = browserShortcuts
        self.applications = applications
    }
    func isBrowserEnabled(_ browser: BrowserKind) -> Bool { !disabledBrowsers.contains(browser) }
    func application(for target: RouteTarget) -> LinkApplication? {
        guard let id = target.applicationBundleIdentifier else { return nil }
        return applications.first { $0.id == id }
    }
    func isTargetEnabled(_ target: RouteTarget) -> Bool {
        if target.applicationBundleIdentifier != nil { return application(for: target)?.enabled == true }
        return target.browser.map(isBrowserEnabled) == true
    }
    static var `default`: AppSettings {
        AppSettings(fallbackMode: .picker, defaultTarget: RouteTarget(browser: .safari), rules: [], alwaysShowPicker: true)
    }
}

struct RoutingContext {
    let url: URL
    let sourceApp: String?
}

enum PickosaurusError: LocalizedError {
    case unsupportedURL
    case browserNotInstalled(BrowserKind)
    case destinationNotFound
    case destinationDisabled
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            return "Pickosaurus opens HTTP and HTTPS web links only."
        case .browserNotInstalled(let browser):
            return "\(browser.displayName) is not installed."
        case .destinationNotFound:
            return "The selected browser could not be found."
        case .destinationDisabled:
            return "This browser is disabled. Enable it in Settings → Browsers to open links in it."
        case .launchFailed(let message):
            return "Failed to open link: \(message)"
        }
    }
}

/// Compiling twice per regex rule per click is unnecessary. Foundation expressions
/// are immutable; NSCache bounds retained patterns and handles concurrent access.
private enum CompiledRuleRegex {
    private static let cache: NSCache<NSString, NSRegularExpression> = {
        let cache = NSCache<NSString, NSRegularExpression>()
        cache.countLimit = 128
        cache.totalCostLimit = 1_048_576
        return cache
    }()

    static func expression(for pattern: String) -> NSRegularExpression? {
        let key = pattern as NSString
        if let expression = cache.object(forKey: key) { return expression }
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        cache.setObject(expression, forKey: key, cost: pattern.utf8.count)
        return expression
    }
}
