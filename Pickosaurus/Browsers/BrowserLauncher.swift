import AppKit
import Foundation

struct BrowserLauncher {
    /// Let the browser itself choose its current/default profile. No scripting or profile arguments.
    @MainActor
    func openBrowser(url: URL, browser: BrowserKind) async throws {
        guard let applicationURL = browser.installedAppURL else {
            throw PickosaurusError.browserNotInstalled(browser)
        }
        try await openWithWorkspace(url: url, applicationURL: applicationURL)
    }

    @MainActor
    func openWithWorkspace(url: URL, applicationURL: URL) async throws {
        guard WebURL.isAllowed(url) else { throw PickosaurusError.unsupportedURL }
        RoutingPerformance.launchRequested()
        defer { RoutingPerformance.launchCompleted() }
        _ = try await NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: NSWorkspace.OpenConfiguration())
    }

}
