import AppKit

struct LinkApplication: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var path: String
    var enabled = true
    var shortcut: String?

    var target: RouteTarget { RouteTarget(applicationBundleIdentifier: id) }
    var isZoom: Bool { id == "us.zoom.xos" }

    static func isAllowedDestination(_ id: String) -> Bool {
        !id.isEmpty && !["com.pickosaurus.app", "com.pickosaurus.debug", "com.pickosaurus.checks", Bundle.main.bundleIdentifier].compactMap({ $0 }).contains(id)
    }

    /// Resolve by identity after an app moves; never trust a replacement at the saved path.
    var applicationURL: URL? {
        guard Self.isAllowedDestination(id) else { return nil }
        let candidates = [NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), URL(fileURLWithPath: path)].compactMap { $0 }
        return candidates.first { $0.pathExtension == "app" && Bundle(url: $0)?.bundleIdentifier == id }
    }

    func urlToOpen(_ url: URL) throws -> URL {
        guard WebURL.isAllowed(url) else { throw PickosaurusError.unsupportedURL }
        if isZoom {
            guard let meeting = ZoomMeetingLink.convert(url) else { throw ApplicationLaunchError.unsupportedZoomLink }
            return meeting
        }
        return url
    }
}

enum ZoomMeetingLink {
    /// Only meeting invitations are translated. Web-only Zoom flows keep their browser behavior.
    static func convert(_ url: URL) -> URL? {
        guard WebURL.isAllowed(url), let source = URLComponents(url: url, resolvingAgainstBaseURL: false),
              source.user == nil, source.password == nil, source.port == nil,
              let host = source.host?.lowercased(),
              ["zoom.us", "zoom.com"].contains(where: { host == $0 || host.hasSuffix("." + $0) }) else { return nil }
        let parts = source.path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].isEmpty, parts[1] == "j",
              parts[2].range(of: #"^[0-9]{9,11}\z"#, options: .regularExpression) != nil else { return nil }
        let items = source.queryItems ?? []
        // Registration/authentication links must complete their web flow first.
        guard items.allSatisfy({ ["pwd", "omn", "from"].contains($0.name) }),
              items.filter({ $0.name == "pwd" }).count <= 1 else { return nil }
        var destination = URLComponents()
        destination.scheme = "zoommtg"
        destination.host = host
        destination.path = "/join"
        destination.queryItems = [URLQueryItem(name: "confno", value: String(parts[2]))]
            + items.filter { $0.name == "pwd" }
        destination.percentEncodedQuery = destination.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return destination.url
    }
}

/// Avoid automatically sending a link back to an app that just returned it to us.
struct ApplicationHandoffTracker {
    private var entries: [URL: (id: String, date: Date)] = [:]

    mutating func record(_ url: URL, applicationID: String, now: Date = Date()) {
        prune(now: now)
        if entries.count >= 100 { entries.removeAll() }
        entries[url] = (applicationID, now)
    }

    mutating func wasReturned(_ url: URL, sourceApp: String?, now: Date = Date()) -> Bool {
        prune(now: now)
        guard let sourceApp, let entry = entries[url] else { return false }
        return entry.id == sourceApp
    }

    mutating func remove(_ url: URL) { entries.removeValue(forKey: url) }

    private mutating func prune(now: Date) {
        entries = entries.filter { now.timeIntervalSince($0.value.date) < 30 }
    }
}

enum ApplicationLaunchError: LocalizedError {
    case unavailable
    case selfDestination
    case unsupportedZoomLink
    case shortcutInUse(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "This application is unavailable or disabled. Add or enable it in Settings → Applications."
        case .selfDestination: return "Pickosaurus cannot be added as its own link destination."
        case .unsupportedZoomLink: return "Use a standard Zoom meeting invitation (/j/meeting-ID). Open personal-room, registration and sign-in links in a browser."
        case .shortcutInUse(let name): return "That key is already assigned to \(name). Change its shortcut first."
        }
    }
}

struct ApplicationLauncher {
    @MainActor
    func open(_ url: URL, in application: LinkApplication) async throws {
        guard application.enabled, let appURL = application.applicationURL else { throw ApplicationLaunchError.unavailable }
        let link = try application.urlToOpen(url)
        RoutingPerformance.launchRequested()
        defer { RoutingPerformance.launchCompleted() }
        _ = try await NSWorkspace.shared.open([link], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
