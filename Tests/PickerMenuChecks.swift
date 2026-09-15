import AppKit
@testable import Pickosaurus

@main
struct PickerMenuChecks {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let config = folder.appendingPathComponent("config.json")
        let firefox = BrowserDestination(browser: .firefox)
        let chrome = BrowserDestination(browser: .chrome)
        let target = RouteTarget(browser: .firefox)
        let rule = RoutingRule(name: "All example links", priority: 0, matchers: [RuleMatcher(kind: .hostSuffix, value: "example.com")], target: target)
        var settings = AppSettings(fallbackMode: .silent, defaultTarget: target, rules: [rule])
        let url = URL(string: "https://example.com/first?secret=not-logged")!
        let context = RoutingContext(url: url, sourceApp: "com.example.sender")
        settings.alwaysShowPicker = true
        try JSONEncoder().encode(settings).write(to: config)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: config))
        precondition(decoded.alwaysShowPicker)
        let engine = RuleEngine()
        guard case .picker = engine.decision(for: context, settings: settings, hasEnabledDefault: true) else { fatalError("Rule bypassed always-show setting") }
        precondition(engine.matchingRule(for: context, in: settings) == nil)
        settings.alwaysShowPicker = false
        guard case .rule = engine.decision(for: context, settings: settings, hasEnabledDefault: true) else { fatalError("Disabling always-show lost rules") }
        var defaultLookups = 0
        func resolveDefault() -> Bool { defaultLookups += 1; return true }
        _ = engine.decision(for: context, settings: settings, hasEnabledDefault: resolveDefault())
        precondition(defaultLookups == 0, "A matching rule must not resolve fallback applications")
        settings.rules = []
        settings.fallbackMode = .picker
        _ = engine.decision(for: context, settings: settings, hasEnabledDefault: resolveDefault())
        precondition(defaultLookups == 0, "Picker fallback must not resolve applications")
        settings.fallbackMode = .silent
        _ = engine.decision(for: context, settings: settings, hasEnabledDefault: resolveDefault())
        precondition(defaultLookups == 1)
        print("PASS: fallback application lookup happens only when automatic fallback is needed")
        print("PASS: always-show preference persists, bypasses rules/defaults and restores existing routing when off")

        var discoveries = 0
        let store = SettingsStore(configURL: config, discoverBrowsers: { discoveries += 1; return [firefox, chrome] })
        store.loadBrowsersIfNeeded()
        store.loadBrowsersIfNeeded()
        precondition(discoveries == 1)
        precondition(RuleTester.test(url: url, store: store).detail.contains("Always show picker"))
        var emptyDiscoveries = 0
        let empty = SettingsStore(configURL: folder.appendingPathComponent("empty.json"), discoverBrowsers: { emptyDiscoveries += 1; return [] })
        empty.loadBrowsersIfNeeded()
        empty.loadBrowsersIfNeeded()
        precondition(emptyDiscoveries == 1)
        empty.reloadBrowsers()
        precondition(emptyDiscoveries == 2)
        print("PASS: loaded and empty discovery results are reused; explicit refresh still discovers again")

        var iconLoads = 0
        let controller = PickerMenuController(browserIcon: { _ in iconLoads += 1; return NSImage(size: NSSize(width: 18, height: 18)) })
        let menu = controller.prepare(settingsStore: store)
        precondition(controller.responds(to: NSSelectorFromString("menuHasKeyEquivalent:forEvent:target:action:")))
        precondition(menu.autoenablesItems == false && iconLoads == 2)
        precondition(menu.items.last?.view is PickerMenuHeader)
        precondition(menu.minimumWidth == 280)
        let firefoxItem = menu.items.first { ($0.representedObject as? RouteTarget) == target }!
        precondition(firefoxItem.keyEquivalent == "f" && firefoxItem.keyEquivalentModifierMask.isEmpty)
        precondition(firefoxItem.title == "Firefox")
        precondition(firefoxItem.image?.size == NSSize(width: 32, height: 32))
        for _ in 0..<100 { controller.prepareForPresentation(url: url, settingsStore: store) }
        precondition(controller.menu === menu && iconLoads == 2 && controller.rebuildCount == 1)
        precondition(menu.items.last?.title == "example.com")
        precondition(!menu.items.contains { $0.title.contains("secret") })
        let copyItem = menu.items.first { $0.title == "Copy Link" }!
        precondition(copyItem.isEnabled && copyItem.keyEquivalent == "c" && copyItem.keyEquivalentModifierMask == [.command])
        try store.setBrowserEnabled(false, for: firefox)
        controller.prepare(settingsStore: store)
        precondition(!controller.menu.items.contains { ($0.representedObject as? RouteTarget) == target })
        try store.setBrowserEnabled(true, for: firefox)
        try store.setBrowserShortcut("1", for: .firefox)
        controller.prepare(settingsStore: store)
        precondition(controller.menu.items.first { ($0.representedObject as? RouteTarget) == target }?.keyEquivalent == "1")
        controller.invalidate()
        let rebuilds = controller.rebuildCount
        controller.prepare(settingsStore: store)
        precondition(controller.rebuildCount == rebuilds + 1)
        print("PASS: menu and icons are cached; settings/availability changes invalidate; native shortcut delegate and plain-key items are connected")

        // Inject a bundle resolver fixture; no third-party application is launched.
        let zoomURL = folder.appendingPathComponent("Zoom.app")
        let contents = zoomURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "us.zoom.xos", "CFBundleName": "Zoom", "CFBundlePackageType": "APPL"], format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        try store.addApplication(InstalledApplication(url: zoomURL)!)
        controller.prepareForPresentation(url: url, settingsStore: store)
        let zoomItem = controller.menu.items.first { ($0.representedObject as? RouteTarget)?.applicationBundleIdentifier == "us.zoom.xos" }!
        precondition(!zoomItem.isEnabled)
        let meeting = URL(string: "https://zoom.us/j/12345678901?pwd=secret")!
        controller.prepareForPresentation(url: meeting, settingsStore: store)
        precondition(zoomItem.isEnabled)
        controller.prepareForPresentation(url: url, settingsStore: store)
        precondition(!zoomItem.isEnabled)
        print("PASS: cached Zoom rows update support for each URL without retaining a previous link's availability")

        var queue = PickerRequestQueue()
        let firstPoint = NSPoint(x: 140, y: 220)
        precondition(queue.append(context, at: firstPoint))
        let first = queue.current!
        precondition(!queue.append(context, at: .zero))
        let second = RoutingContext(url: URL(string: "https://example.com/second")!, sourceApp: "com.example.other")
        precondition(queue.append(second, at: NSPoint(x: -400, y: 300)))
        precondition(queue.current?.id == first.id && queue.current?.location == firstPoint)
        precondition(!queue.finish(UUID()))
        precondition(queue.finish(first.id))
        precondition(queue.current?.context.url == second.url && queue.current?.context.sourceApp == second.sourceApp)
        precondition(!queue.finish(first.id))
        precondition(queue.finish(queue.current!.id))
        precondition(queue.current == nil)
        precondition(queue.append(context, at: .zero))
        precondition(queue.current?.id != first.id)
        for index in 0..<200 { queue.append(RoutingContext(url: URL(string: "https://example.com/\(index)")!, sourceApp: nil), at: .zero) }
        precondition(queue.requests.count == 100)
        print("PASS: rapid links queue in order with original positions/senders; duplicates, stale selections and unbounded growth are blocked")

        let primary = NSRect(x: 0, y: 24, width: 1440, height: 876)
        let left = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let above = NSRect(x: 0, y: 900, width: 1280, height: 800)
        let frames = [primary, left, above]
        precondition(PickerMenuPosition.anchor(at: firstPoint, visibleFrames: frames) == NSPoint(x: 146, y: 214))
        for (point, screen) in [(NSPoint(x: -800, y: 800), left), (NSPoint(x: 100, y: 1100), above), (NSPoint(x: 1439, y: 25), primary), (NSPoint(x: -1919, y: 1079), left)] {
            precondition(screen.contains(PickerMenuPosition.anchor(at: point, visibleFrames: frames)))
        }
        precondition(left.contains(PickerMenuPosition.anchor(at: NSPoint(x: -2500, y: 500), visibleFrames: frames)))
        precondition(PickerMenuPosition.anchor(at: firstPoint, visibleFrames: []) == firstPoint)
        print("PASS: pointer anchoring handles screen edges, negative coordinates, stacked displays and disconnected displays")

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let exact = "https://example.com/a%2Fb?x=a%2Bb&pwd=value%3D#section"
        try LinkClipboard.copy(URL(string: exact)!, to: pasteboard)
        precondition(pasteboard.string(forType: .string) == exact)
        do {
            try LinkClipboard.copy(URL(string: "file:///tmp/no-copy")!, to: pasteboard)
            preconditionFailure("Non-web URL was copied")
        } catch {}
        precondition(pasteboard.string(forType: .string) == exact)
        let copyStore = SettingsStore(configURL: folder.appendingPathComponent("copy.json"), discoverBrowsers: { [] })
        let copyMenu = PickerMenuController().prepare(settingsStore: copyStore)
        precondition(copyMenu.items.contains { $0.title == "Copy Link" && $0.isEnabled })
        let router = URLRouter(settingsStore: copyStore)
        router.handleOpenURLs([url, meeting])
        let firstRequest = router.pickerRequest!.id
        router.cancelPicker(requestID: UUID())
        precondition(router.pickerRequest?.id == firstRequest)
        router.copyPickerLink(requestID: UUID(), to: pasteboard)
        precondition(router.pickerRequest?.id == firstRequest && pasteboard.string(forType: .string) == exact)
        router.copyPickerLink(requestID: firstRequest, to: pasteboard)
        precondition(pasteboard.string(forType: .string) == url.absoluteString && router.pendingPickerURL == meeting)
        router.copyPickerLink(requestID: firstRequest, to: pasteboard)
        precondition(pasteboard.string(forType: .string) == url.absoluteString && router.pendingPickerURL == meeting)
        router.copyPickerLink(requestID: router.pickerRequest!.id, to: pasteboard)
        precondition(pasteboard.string(forType: .string) == meeting.absoluteString && router.pendingPickerURL == nil)
        print("PASS: copy preserves the original web URL, works without destinations, rejects stale requests, and advances queued links without launching")

        var samples: [Double] = []
        for _ in 0..<1000 {
            let start = ProcessInfo.processInfo.systemUptime
            controller.prepareForPresentation(url: url, settingsStore: store)
            samples.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
        }
        samples.sort()
        print(String(format: "BENCH: warm menu preparation, 1000 runs: median %.3f ms; p95 %.3f ms (excludes OS delivery, display and browser launch)", samples[500], samples[950]))

        if ProcessInfo.processInfo.environment["PICKOSAURUS_MENU_SMOKE"] == "1" {
            setbuf(stdout, nil)
            try store.setBrowserShortcut("f", for: .firefox)
            NSApp.setActivationPolicy(.accessory)
            NSApp.finishLaunching()
            let smoke = PickerMenuController()
            let cases: [(String, NSEvent.ModifierFlags, PickerMenuController.Selection)] = [
                ("f", [], .destination(target)), ("F", [.shift], .destination(target)),
                ("c", [], .destination(RouteTarget(browser: .chrome))),
                ("c", [.command], .copyLink), ("\u{1b}", [], .cancelled)
            ]
            for (characters, modifiers, expected) in cases {
                var delivered = false
                var timedOut = false
                let delivery = Timer(timeInterval: 0.15, repeats: false) { _ in
                    delivered = true
                    let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
                        modifierFlags: modifiers,
                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                        characters: characters, charactersIgnoringModifiers: characters.lowercased(),
                        isARepeat: false, keyCode: characters == "\u{1b}" ? 53 : 3)!
                    MainActor.assumeIsolated {
                        if characters == "\u{1b}" { smoke.close() }
                        else { _ = smoke.menu.performKeyEquivalent(with: event) }
                    }
                }
                let timeout = Timer(timeInterval: 2, repeats: false) { _ in
                    timedOut = true
                    MainActor.assumeIsolated { smoke.close() }
                }
                RunLoop.main.add(delivery, forMode: .eventTracking)
                RunLoop.main.add(timeout, forMode: .eventTracking)
                let request = PickerRequest(context: context, location: NSEvent.mouseLocation)
                let start = ProcessInfo.processInfo.systemUptime
                let result = smoke.selection(for: request, settingsStore: store)
                delivery.invalidate()
                timeout.invalidate()
                guard result == expected, NSApp.activationPolicy() == .accessory else {
                    print("FAIL: native menu key \(characters): \(result); delivered=\(delivered), timedOut=\(timedOut), seconds=\(ProcessInfo.processInfo.systemUptime - start)")
                    Darwin.exit(1)
                }
            }
            print("PASS: live native menu distinguishes plain C from Command-C, dispatches browser keys and cancellation, without launching or a Dock-policy change")
        }
    }
}
