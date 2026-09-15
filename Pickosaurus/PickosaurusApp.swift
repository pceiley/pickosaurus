import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isDefaultBrowser = false
    private var isChangingDefault = false

    private init() {}

    func refreshDefaultBrowserStatus() {
        isDefaultBrowser = DefaultBrowserService.isDefaultBrowser
    }

    func registerAsDefaultBrowser() {
        guard !isChangingDefault else { return }
        isChangingDefault = true
        Task {
            defer { isChangingDefault = false }
            do {
                try await DefaultBrowserService.setAsDefaultBrowser()
                refreshDefaultBrowserStatus()
                if !isDefaultBrowser { showDefaultBrowserError("macOS has not applied the default browser change.") }
            } catch {
                refreshDefaultBrowserStatus()
                let error = error as NSError
                if (error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError)
                    || (error.domain == NSOSStatusErrorDomain && error.code == -128) { return }
                showDefaultBrowserError(error.localizedDescription)
            }
        }
    }

    private func showDefaultBrowserError(_ message: String) {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Pickosaurus"
        let alert = NSAlert()
        alert.messageText = "Couldn’t Change Default Browser"
        alert.informativeText = "\(message)\n\nChoose \(name) in System Settings → Desktop & Dock → Default web browser."
        alert.alertStyle = .warning
        AppWindowPresentation.shared.runModal(alert)
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        RoutingPerformance.linkReceived()
        let sourceApp = SourceApplicationResolver.currentBundleIdentifier()
        let location = NSEvent.mouseLocation
        Task { @MainActor in
            URLRouter.shared.handleOpenURLs(urls, sourceApp: sourceApp, location: location)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            SettingsStore.shared.loadBrowsersIfNeeded()
            PickerMenuController.shared.prepare(settingsStore: .shared)

            AppState.shared.refreshDefaultBrowserStatus()

            // Update checks are user-initiated; launching the app makes no update request.
            UpdateController.shared.consumePostUpdateNoticeIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            AppState.shared.refreshDefaultBrowserStatus()
        }
    }
}

@main
struct PickosaurusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var appState = AppState.shared
    @StateObject private var urlRouter = URLRouter.shared
    @StateObject private var updateController = UpdateController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(settingsStore)
                .environmentObject(appState)
                .environmentObject(urlRouter)
                .environmentObject(updateController)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .accessibilityLabel(BuildConfiguration.isDebugPreview ? "Pickosaurus Debug" : "Pickosaurus")
        }
        .menuBarExtraStyle(.window)
    }
}
