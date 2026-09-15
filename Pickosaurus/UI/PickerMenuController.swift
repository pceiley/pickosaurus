import AppKit
import os

/// A native tracking menu needs no app activation, hosting view, or Dock-policy transition.
@MainActor
final class PickerMenuController: NSObject, NSMenuDelegate {
    static let shared = PickerMenuController()
    private static let timingLog = OSLog(subsystem: "com.pickosaurus", category: .pointsOfInterest)

    private var header = PickerMenuHeader()
    private(set) var menu = NSMenu(title: "Open Link In")
    private var cachedStore: ObjectIdentifier?
    private var cachedRevision: UInt64?
    private var applicationItems: [(NSMenuItem, LinkApplication)] = []
    private var shortcuts: [String: NSMenuItem] = [:]
    private var selectedAction: Selection = .cancelled
    private var isTracking = false
    private var isScheduled = false
    private var shortcutItem: NSMenuItem?
    private(set) var rebuildCount = 0
    private let browserIcon: (BrowserDestination) -> NSImage
    private let applicationIcon: (LinkApplication) -> NSImage

    init(browserIcon: @escaping (BrowserDestination) -> NSImage = {
        BrowserIconProvider.icon(for: $0.browser, size: 32)
    }, applicationIcon: @escaping (LinkApplication) -> NSImage = { app in
        app.applicationURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
    }) {
        self.browserIcon = browserIcon
        self.applicationIcon = applicationIcon
        super.init()
    }

    func invalidate() { cachedRevision = nil }

    func prepareForPresentation(url: URL, settingsStore: SettingsStore) {
        prepare(settingsStore: settingsStore)
        let host = String((url.host ?? "Choose a destination").prefix(253))
        menu.items.last?.title = host
        header.update(host: host)
        for (item, app) in applicationItems {
            item.isEnabled = (try? app.urlToOpen(url)) != nil
            item.toolTip = item.isEnabled ? nil : "Open this link in a browser."
        }
    }

    /// Warm once at startup; subsequent links only change the host and URL-dependent availability.
    @discardableResult
    func prepare(settingsStore store: SettingsStore) -> NSMenu {
        guard cachedStore != ObjectIdentifier(store) || cachedRevision != store.destinationRevision else { return menu }
        cachedStore = ObjectIdentifier(store)
        cachedRevision = store.destinationRevision
        rebuildCount += 1
        menu = NSMenu(title: "Open Link In")
        menu.autoenablesItems = false
        menu.delegate = self
        menu.minimumWidth = 280
        menu.font = .systemFont(ofSize: 13, weight: .medium)
        applicationItems = []
        shortcuts = [:]
        header = PickerMenuHeader()
        let headerItem = NSMenuItem(title: "Open Link In", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        headerItem.view = header

        let settings = store.settings
        let browsers = store.enabledBrowsers
        for destination in browsers {
            let item = destinationItem(title: destination.displayName, target: destination.target,
                image: browserIcon(destination))
            if let key = settings.browserShortcuts[destination.browser.rawValue].flatMap(PickerShortcuts.normalized),
               PickerShortcuts.browser(for: key, settings: settings) == destination.browser {
                assign(key, to: item)
            }
        }
        let applications = store.enabledApplications
        if !applications.isEmpty && !browsers.isEmpty { menu.addItem(.separator()) }
        for app in applications {
            let item = destinationItem(title: app.name, target: app.target, image: applicationIcon(app))
            applicationItems.append((item, app))
            if let key = app.shortcut.flatMap(PickerShortcuts.normalized),
               PickerShortcuts.application(for: key, settings: settings)?.id == app.id { assign(key, to: item) }
        }
        if browsers.isEmpty && applications.isEmpty { addHeading("No enabled destinations") }
        menu.addItem(.separator())
        let copyItem = NSMenuItem(title: "Copy Link", action: #selector(copyLink), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.image?.size = NSSize(width: 16, height: 16)
        copyItem.attributedTitle = utilityTitle("Copy Link")
        copyItem.toolTip = "Copy the original link without opening it."
        menu.addItem(copyItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.image?.size = NSSize(width: 16, height: 16)
        settingsItem.attributedTitle = utilityTitle("Settings…")
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(headerItem)
        return menu
    }

    func show(settingsStore: SettingsStore, urlRouter: URLRouter) {
        // NSMenu runs a nested event loop. Never enter a second tracking loop for a new URL.
        guard !isTracking, !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.async { [weak self, weak settingsStore, weak urlRouter] in
            guard let self else { return }
            self.isScheduled = false
            guard let settingsStore, let urlRouter, let request = urlRouter.pickerRequest else { return }
            self.track(request, settingsStore: settingsStore, urlRouter: urlRouter)
        }
    }

    private func track(_ request: PickerRequest, settingsStore: SettingsStore, urlRouter: URLRouter) {
        let result = selection(for: request, settingsStore: settingsStore)
        // Launch only after native menu tracking has unwound and released focus.
        switch result {
        case .destination(let target): urlRouter.completePickerSelection(requestID: request.id, target: target)
        case .copyLink: urlRouter.copyPickerLink(requestID: request.id)
        case .cancelled, .settings: urlRouter.cancelPicker(requestID: request.id)
        }
        if case .settings = result { SettingsWindowController.shared.show(settingsStore: settingsStore, appState: .shared) }
    }

    enum Selection: Equatable {
        case destination(RouteTarget)
        case copyLink
        case settings
        case cancelled
    }

    func selection(for request: PickerRequest, settingsStore: SettingsStore) -> Selection {
        let signpost = OSSignpostID(log: Self.timingLog)
        os_signpost(.begin, log: Self.timingLog, name: "Prepare picker", signpostID: signpost)
        prepareForPresentation(url: request.context.url, settingsStore: settingsStore)
        selectedAction = .cancelled
        shortcutItem = nil
        isTracking = true
        os_signpost(.end, log: Self.timingLog, name: "Prepare picker", signpostID: signpost)
        menu.popUp(positioning: nil,
                   at: PickerMenuPosition.anchor(at: request.location, visibleFrames: NSScreen.screens.map(\.visibleFrame)),
                   in: nil)
        isTracking = false
        return selectedAction
    }

    func close() { if isTracking { menu.cancelTrackingWithoutAnimation() } }

    private func utilityTitle(_ title: String) -> NSAttributedString {
        NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 13)])
    }

    private func addHeading(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func destinationItem(title: String, target: RouteTarget, image: NSImage?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(choose(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = target
        item.image = image?.copy() as? NSImage
        item.image?.size = NSSize(width: 32, height: 32)
        menu.addItem(item)
        return item
    }

    private func assign(_ key: String, to item: NSMenuItem) {
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = []
        shortcuts[key] = item
    }

    @objc private func choose(_ item: NSMenuItem) {
        guard isTracking, item.isEnabled else { return }
        RoutingPerformance.destinationSelected()
        guard let target = item.representedObject as? RouteTarget else { return }
        selectedAction = .destination(target)
        menu.cancelTrackingWithoutAnimation()
    }

    func menuWillOpen(_ menu: NSMenu) { RoutingPerformance.pickerWillOpen() }

    @objc private func openSettings() {
        selectedAction = .settings
        menu.cancelTrackingWithoutAnimation()
    }

    @objc private func copyLink() {
        guard isTracking else { return }
        selectedAction = .copyLink
        menu.cancelTrackingWithoutAnimation()
    }

    @objc private func chooseShortcut() {
        if let shortcutItem { choose(shortcutItem) }
    }

    func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent,
                              target: AutoreleasingUnsafeMutablePointer<AnyObject?>,
                              action: UnsafeMutablePointer<Selector?>) -> Bool {
        guard isTracking else { return false }
        // Command-C copies; plain C remains a configurable destination shortcut.
        if event.charactersIgnoringModifiers?.lowercased() == "c", event.modifierFlags.contains(.command) {
            target.pointee = nil
            action.pointee = nil
            if PickerShortcuts.isCopyEvent(event) {
                target.pointee = self
                action.pointee = #selector(copyLink)
            }
            return true
        }
        // Consume assigned keys even when disabled/repeated, preventing native fallback
        // from selecting a different row. Arrow keys, Return and Escape stay native.
        guard let characters = event.characters, let key = PickerShortcuts.normalized(characters),
              let item = shortcuts[key] else { return false }
        target.pointee = nil
        action.pointee = nil
        if PickerShortcuts.key(from: event) != nil && item.isEnabled {
            shortcutItem = item
            target.pointee = self
            action.pointee = #selector(chooseShortcut)
        }
        return true
    }
}
