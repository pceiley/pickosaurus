import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published private(set) var settings: AppSettings { didSet { destinationRevision &+= 1 } }
    @Published private(set) var browsers: [BrowserDestination] = [] { didSet { destinationRevision &+= 1 } }
    private(set) var destinationRevision: UInt64 = 0
    private(set) var hasLoadedBrowsers = false

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let configURL: URL
    private let discoverBrowsers: () -> [BrowserDestination]

    init(configURL: URL? = nil, discoverBrowsers: @escaping () -> [BrowserDestination] = BrowserCatalog.discover) {
        self.discoverBrowsers = discoverBrowsers
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        self.configURL = configURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(BuildConfiguration.settingsDirectoryName, isDirectory: true)
            .appendingPathComponent("config.json")

        settings = Self.loadSettings(from: self.configURL, decoder: decoder) ?? .default
    }

    func reloadBrowsers() {
        hasLoadedBrowsers = true
        browsers = discoverBrowsers()
    }

    func loadBrowsersIfNeeded() {
        guard !hasLoadedBrowsers else { return }
        reloadBrowsers()
    }

    func save() throws {
        try persist(settings)
    }

    private func persist(_ settings: AppSettings) throws {
        let directory = configURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let data = try encoder.encode(settings)
        try data.write(to: configURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
    }

    /// Hidden browsers must not reserve keys the user has no row to edit.
    /// Prune on an explicit settings edit, keeping startup discovery read-only.
    private func releaseUndetectedBrowserKeys(in settings: inout AppSettings) {
        guard hasLoadedBrowsers else { return }
        let installed = Set(browsers.map { $0.browser.rawValue })
        settings.browserShortcuts = settings.browserShortcuts.filter { installed.contains($0.key) }
    }

    func setBrowserShortcut(_ value: String?, for browser: BrowserKind) throws {
        var updated = settings
        releaseUndetectedBrowserKeys(in: &updated)
        if let value {
            guard let key = PickerShortcuts.normalized(value) else { throw PickerShortcutError.invalidKey }
            if let app = updated.applications.first(where: { $0.shortcut.flatMap(PickerShortcuts.normalized) == key }) {
                throw ApplicationLaunchError.shortcutInUse(app.name)
            }
            if let other = BrowserKind.allCases.first(where: {
                $0 != browser && updated.browserShortcuts[$0.rawValue].flatMap(PickerShortcuts.normalized) == key
            }) {
                throw PickerShortcutError.alreadyAssigned(other)
            }
            updated.browserShortcuts[browser.rawValue] = key
        } else {
            updated.browserShortcuts.removeValue(forKey: browser.rawValue)
        }
        try persist(updated)
        settings = updated
    }

    var enabledBrowsers: [BrowserDestination] {
        browsers.filter { isBrowserEnabled($0) }
    }

    var enabledApplications: [LinkApplication] {
        settings.applications.filter { $0.enabled && $0.applicationURL != nil }
    }

    var hasEnabledDefaultDestination: Bool {
        isAvailable(settings.defaultTarget)
    }

    func isAvailable(_ target: RouteTarget) -> Bool {
        if target.applicationBundleIdentifier != nil {
            guard let app = settings.application(for: target), app.enabled else { return false }
            return app.applicationURL != nil
        }
        return destination(for: target).map(isBrowserEnabled) == true
    }

    func destinationLabel(for target: RouteTarget) -> String {
        settings.application(for: target)?.name ?? destination(for: target)?.displayName ?? target.label
    }

    func addApplication(_ app: InstalledApplication) throws {
        guard LinkApplication.isAllowedDestination(app.id) else { throw ApplicationLaunchError.selfDestination }
        var updated = settings
        if let index = updated.applications.firstIndex(where: { $0.id == app.id }) {
            updated.applications[index].name = app.name
            updated.applications[index].path = app.url.path
        } else {
            updated.applications.append(LinkApplication(id: app.id, name: app.name, path: app.url.path))
        }
        try persist(updated)
        settings = updated
    }

    func updateApplication(_ application: LinkApplication) throws {
        guard let index = settings.applications.firstIndex(where: { $0.id == application.id }) else { return }
        var updated = settings
        releaseUndetectedBrowserKeys(in: &updated)
        var application = application
        if let value = application.shortcut {
            guard let key = PickerShortcuts.normalized(value) else { throw PickerShortcutError.invalidKey }
            if let browser = BrowserKind.allCases.first(where: { updated.browserShortcuts[$0.rawValue].flatMap(PickerShortcuts.normalized) == key }) {
                throw PickerShortcutError.alreadyAssigned(browser)
            }
            if let other = settings.applications.first(where: { $0.id != application.id && $0.shortcut.flatMap(PickerShortcuts.normalized) == key }) {
                throw ApplicationLaunchError.shortcutInUse(other.name)
            }
            application.shortcut = key
        }
        updated.applications[index] = application
        try persist(updated)
        settings = updated
    }

    func removeApplication(id: String) throws {
        var updated = settings
        updated.applications.removeAll { $0.id == id }
        // Rules retain the missing destination and are skipped until the app is added again.
        try persist(updated)
        settings = updated
    }

    func addZoomRule(for app: LinkApplication) throws {
        guard app.isZoom, settings.applications.contains(where: { $0.id == app.id }),
              !settings.rules.contains(where: { $0.target == app.target }) else { return }
        var updated = settings
        updated.rules.append(RoutingRule(name: "Zoom meetings", priority: (updated.rules.map(\.priority).max() ?? -1) + 1,
            matchers: [RuleMatcher(kind: .urlRegex, value: #"(?i)^https?://(?:[a-z0-9-]+\.)*zoom\.(?:us|com)/j/[0-9]{9,11}(?:[?#]|$)"#)], target: app.target))
        try persist(updated)
        settings = updated
    }

    func isBrowserEnabled(_ destination: BrowserDestination) -> Bool {
        settings.isBrowserEnabled(destination.browser)
    }

    func setBrowserEnabled(_ enabled: Bool, for destination: BrowserDestination) throws {
        var updated = settings
        if enabled { updated.disabledBrowsers.remove(destination.browser) }
        else { updated.disabledBrowsers.insert(destination.browser) }
        try persist(updated)
        settings = updated
    }

    func updateSettings(_ transform: (inout AppSettings) -> Void) throws {
        var updated = settings
        transform(&updated)
        try persist(updated)
        settings = updated
    }

    /// A nil destination means the picker is the fallback.
    var fallbackDestination: RouteTarget? {
        settings.fallbackMode == .picker ? nil : settings.defaultTarget
    }

    func setFallbackDestination(_ target: RouteTarget?) throws {
        if let target, !isAvailable(target) { return }
        var updated = settings
        updated.fallbackMode = target == nil ? .picker : .silent
        if let target { updated.defaultTarget = target }
        try persist(updated)
        settings = updated
    }

    func addRule(_ rule: RoutingRule) throws {
        try updateSettings { settings in
            var rule = rule
            rule.priority = (settings.rules.map(\.priority).max() ?? -1) + 1
            settings.rules.append(rule)
        }
    }

    func updateRule(_ rule: RoutingRule) throws {
        try updateSettings { settings in
            guard let index = settings.rules.firstIndex(where: { $0.id == rule.id }) else { return }
            settings.rules[index] = rule
        }
    }

    func setRuleEnabled(_ enabled: Bool, id: UUID) throws {
        var updated = settings
        guard let index = updated.rules.firstIndex(where: { $0.id == id }) else { return }
        updated.rules[index].enabled = enabled
        try persist(updated)
        settings = updated
    }

    func duplicateRule(id: UUID) throws {
        var updated = settings
        updated.rules.sort { $0.priority < $1.priority }
        guard let index = updated.rules.firstIndex(where: { $0.id == id }) else { return }
        var copy = updated.rules[index]
        copy.id = UUID()
        let baseName = "\(copy.name) Copy"
        copy.name = baseName
        var suffix = 2
        while updated.rules.contains(where: { $0.name == copy.name }) {
            copy.name = "\(baseName) \(suffix)"
            suffix += 1
        }
        updated.rules.insert(copy, at: index + 1)
        for index in updated.rules.indices {
            updated.rules[index].priority = index
        }
        try persist(updated)
        settings = updated
    }

    func deleteRule(id: UUID) throws {
        try updateSettings { settings in
            settings.rules.removeAll { $0.id == id }
            settings.rules.sort { $0.priority < $1.priority }
            for index in settings.rules.indices {
                settings.rules[index].priority = index
            }
        }
    }

    func moveRules(from source: IndexSet, to destination: Int) throws {
        try updateSettings { settings in
            var rules = settings.rules.sorted { $0.priority < $1.priority }
            rules.move(fromOffsets: source, toOffset: destination)
            for index in rules.indices {
                rules[index].priority = index
            }
            settings.rules = rules
        }
    }

    func destination(for target: RouteTarget) -> BrowserDestination? {
        guard target.applicationBundleIdentifier == nil else { return nil }
        return browsers.first { $0.browser == target.browser }
    }

    func browsers(for browser: BrowserKind) -> [BrowserDestination] {
        browsers.filter { $0.browser == browser }
    }

    private static func loadSettings(from url: URL, decoder: JSONDecoder) -> AppSettings? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AppSettings.self, from: data)
    }

}
