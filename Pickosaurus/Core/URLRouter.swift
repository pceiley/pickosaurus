import AppKit
import Foundation

@MainActor
final class URLRouter: ObservableObject {
    static let shared = URLRouter(settingsStore: .shared)

    private var pickerQueue = PickerRequestQueue()
    var pickerRequest: PickerRequest? { pickerQueue.current }
    var pendingPickerURL: URL? { pickerRequest?.context.url }

    private let ruleEngine = RuleEngine()
    private let launcher = BrowserLauncher()
    private let settingsStore: SettingsStore

    /// Links whose open is still on its way to a browser. A link is dropped
    /// while its own open is in flight, so it cannot end up in two tabs when it
    /// arrives twice — macOS re-delivering it, or a second click made while a
    /// cold browser is still starting and nothing has appeared yet.
    private var linksBeingOpened: Set<URL> = []
    private var applicationHandoffs = ApplicationHandoffTracker()

    /// A browser opens its tab shortly after the launcher is done, so a link
    /// stays guarded a moment longer than the open itself takes.
    private static let openSettleDelay: Duration = .seconds(2)

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func handleOpenURLs(_ urls: [URL], sourceApp: String? = nil, location: NSPoint = NSEvent.mouseLocation) {
        for url in urls {
            route(url: url, sourceApp: sourceApp, location: location)
        }
    }

    func route(url: URL, sourceApp: String? = nil, location: NSPoint = NSEvent.mouseLocation) {
        guard WebURL.isAllowed(url) else { return }
        if applicationHandoffs.wasReturned(url, sourceApp: sourceApp) {
            showPicker(url: url, sourceApp: sourceApp, location: location)
            return
        }
        guard !linksBeingOpened.contains(url) else { return }
        settingsStore.loadBrowsersIfNeeded()

        let context = RoutingContext(url: url, sourceApp: sourceApp)
        let settings = settingsStore.settings

        // The every-link workflow never evaluates rules or resolves a default application.
        if settings.alwaysShowPicker {
            showPicker(url: url, sourceApp: sourceApp, location: location)
            return
        }
        switch ruleEngine.decision(for: context, settings: settings, hasEnabledDefault: settingsStore.hasEnabledDefaultDestination) {
        case .picker:
            showPicker(url: url, sourceApp: sourceApp, location: location)
        case .rule(let rule):
            open(url: url, target: rule.target)
        case .defaultTarget(let target):
            open(url: url, target: target)
        }
    }

    func completePickerSelection(requestID: UUID, target: RouteTarget) {
        guard let request = pickerRequest, request.id == requestID else { return }
        guard settingsStore.isAvailable(target) else {
            PickerMenuController.shared.invalidate()
            PickerMenuController.shared.show(settingsStore: settingsStore, urlRouter: self)
            return
        }
        let url = request.context.url
        pickerQueue.finish(requestID)
        open(url: url, target: target)
        showNextPicker()
    }

    func cancelPicker(requestID: UUID? = nil) {
        if let requestID {
            guard pickerQueue.finish(requestID) else { return }
        }
        else { pickerQueue = PickerRequestQueue() }
        PickerMenuController.shared.close()
        showNextPicker()
    }

    func copyPickerLink(requestID: UUID, to pasteboard: NSPasteboard = .general) {
        guard let request = pickerRequest, request.id == requestID else { return }
        do {
            try LinkClipboard.copy(request.context.url, to: pasteboard)
            pickerQueue.finish(requestID)
        } catch {
            showError(error)
        }
        showNextPicker()
    }

    func open(url: URL, target: RouteTarget) {
        guard WebURL.isAllowed(url) else { return }
        // A link is being routed to a browser — never let our own windows steal focus.
        SettingsWindowController.shared.hide()

        if target.applicationBundleIdentifier != nil {
            openApplication(url: url, target: target)
            return
        }

        guard let destination = settingsStore.destination(for: target) else {
            showError(PickosaurusError.destinationNotFound)
            return
        }

        guard settingsStore.isBrowserEnabled(destination) else {
            showError(PickosaurusError.destinationDisabled)
            return
        }

        guard linksBeingOpened.insert(url).inserted else { return }

        Task {
            do {
                try await launcher.openBrowser(url: url, browser: destination.browser)
            } catch {
                linksBeingOpened.remove(url)
                PickerMenuController.shared.invalidate()
                showPicker(url: url, sourceApp: nil)
                showError(error)
                return
            }

            try? await Task.sleep(for: Self.openSettleDelay)
            linksBeingOpened.remove(url)
        }
    }

    private func showPicker(url: URL, sourceApp: String?, location: NSPoint = NSEvent.mouseLocation) {
        pickerQueue.append(RoutingContext(url: url, sourceApp: sourceApp), at: location)
        showNextPicker()
    }

    private func showNextPicker() {
        guard pickerRequest != nil else { return }
        PickerMenuController.shared.show(settingsStore: settingsStore, urlRouter: self)
    }

    private func openApplication(url: URL, target: RouteTarget) {
        guard let app = settingsStore.settings.application(for: target), settingsStore.isAvailable(target) else {
            showError(ApplicationLaunchError.unavailable)
            return
        }
        guard linksBeingOpened.insert(url).inserted else { return }
        applicationHandoffs.record(url, applicationID: app.id)
        Task {
            do {
                try await ApplicationLauncher().open(url, in: app)
            } catch {
                linksBeingOpened.remove(url)
                applicationHandoffs.remove(url)
                PickerMenuController.shared.invalidate()
                showPicker(url: url, sourceApp: nil)
                showError(error)
                return
            }
            try? await Task.sleep(for: Self.openSettleDelay)
            linksBeingOpened.remove(url)
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Pickosaurus"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        AppWindowPresentation.shared.runModal(alert)
    }
}
