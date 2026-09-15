import AppKit

@MainActor
enum DefaultBrowserService {
    static let schemes = ["http", "https"]

    static var isDefaultBrowser: Bool {
        isDefaultBrowser(bundleIdentifier: Bundle.main.bundleIdentifier) { scheme in
            guard let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: scheme + "://example.com")!) else { return nil }
            return Bundle(url: applicationURL)?.bundleIdentifier
        }
    }

    /// Launch Services identifies an app by bundle ID; its selected copy can move.
    /// Debug and release remain distinct identities even when their names are similar.
    static func isDefaultBrowser(bundleIdentifier: String?, handler: (String) -> String?) -> Bool {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
        return schemes.allSatisfy { handler($0) == bundleIdentifier }
    }

    static func setAsDefaultBrowser(
        applicationURL: URL = Bundle.main.bundleURL,
        request: (URL, String) async throws -> Void = { applicationURL, scheme in
            try await NSWorkspace.shared.setDefaultApplication(at: applicationURL, toOpenURLsWithScheme: scheme)
        }
    ) async throws {
        // Stop on failure/cancellation so declining HTTP never triggers a second prompt.
        for scheme in schemes { try await request(applicationURL, scheme) }
    }
}
