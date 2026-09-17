import AppKit
import Sparkle

/// Starts Sparkle only in response to an explicit user action. Automatic checks
/// and downloads are also disabled in Info.plist, so launch performs no update
/// networking or updater work.
@MainActor
final class UpdateController {
    static let shared = UpdateController()

    private var updaterController: SPUStandardUpdaterController?

    private init() {}

    func checkForUpdates() {
        guard !BuildConfiguration.isDebugPreview else {
            showConfigurationError("Updates are disabled in the debug preview. Build a release version to test updates.")
            return
        }
        guard UpdateConfiguration.isConfigured else {
            showConfigurationError("Updates are not configured for this Pickosaurus build.")
            return
        }

        let controller: SPUStandardUpdaterController
        if let updaterController {
            controller = updaterController
        } else {
            controller = SPUStandardUpdaterController(
                startingUpdater: false,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            updaterController = controller
            controller.startUpdater()
        }
        controller.checkForUpdates(nil)
    }

    private func showConfigurationError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Can’t Check for Updates"
        alert.informativeText = message
        alert.alertStyle = .warning
        AppWindowPresentation.shared.runModal(alert)
    }
}
