import AppKit
import Foundation
@testable import Pickosaurus

@main
struct SecurityChecks {
    @MainActor
    static func main() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("pickosaurus-security-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        for value in ["javascript:alert(1)", "file:///tmp/private.html", "data:text/html,test", "ftp://example.com", "https:/missing-host", "https://example.com/" + String(repeating: "x", count: 32_768)] {
            precondition(!WebURL.isAllowed(URL(string: value)!))
        }
        for value in ["https://example.com/?token=private#fragment", "HTTP://localhost:8080/a", "https://[::1]/"] {
            precondition(WebURL.isAllowed(URL(string: value)!))
        }
        let store = SettingsStore(configURL: temporary.appendingPathComponent("settings/config.json"), discoverBrowsers: { [] })
        let router = URLRouter(settingsStore: store)
        router.route(url: URL(string: "javascript:alert(1)")!)
        precondition(router.pendingPickerURL == nil)
        print("PASS: live routing rejects non-web and oversized URLs before setup or launching")

        try store.save()
        let config = temporary.appendingPathComponent("settings/config.json")
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: config.path)
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: config.deletingLastPathComponent().path)
        precondition((fileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        precondition((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        try store.save()
        let replacedAttributes = try FileManager.default.attributesOfItem(atPath: config.path)
        precondition((replacedAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        print("PASS: new and replaced settings remain owner-only")

        precondition(!ReleaseConfiguration.isConfigured)
        precondition(!ReleaseIdentity.isValid(at: temporary))
        precondition(!ReleaseIdentity.isValid(at: temporary, teamIdentifier: "BAD\" OR true"))
        precondition(!ReleaseConfiguration.isValidRepository("owner/repo/../../other"))
        precondition(!ReleaseConfiguration.isValidTeamIdentifier("TEAM123456\n"))
        let repository = "example/pickosaurus"
        precondition(ReleaseConfiguration.isReleaseAssetURL(URL(string: "https://github.com/example/pickosaurus/releases/download/v0.1.0/Pickosaurus-0.1.0.dmg")!, repository: repository))
        for value in ["http://github.com/example/pickosaurus/releases/download/v1/a.dmg", "https://evil.test/example/pickosaurus/releases/download/v1/a.dmg", "https://github.com/other/repo/releases/download/v1/a.dmg", "https://github.com@example.test/example/pickosaurus/releases/download/v1/a.dmg"] {
            precondition(!ReleaseConfiguration.isReleaseAssetURL(URL(string: value)!, repository: repository))
        }
        print("PASS: unconfigured updates fail closed and asset URLs stay in the configured HTTPS repository")

        try checkSwap(in: temporary, missingSource: false)
        try checkSwap(in: temporary, missingSource: true)
        print("PASS: update swap replaces successfully and restores the installed app on rename failure")
    }

    static func checkSwap(in root: URL, missingSource: Bool) throws {
        let directory = root.appendingPathComponent(UUID().uuidString)
        let work = directory.appendingPathComponent("stage with 'quotes'")
        let source = work.appendingPathComponent("Pickosaurus.app")
        let destination = directory.appendingPathComponent("Installed ' app.app")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: destination.appendingPathComponent("marker"))
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        if !missingSource {
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            try Data("new".utf8).write(to: source.appendingPathComponent("marker"))
        }
        let scriptURL = directory.appendingPathComponent("swap.sh")
        // Exercise the filesystem transaction without launching an application.
        let script = UpdateInstaller.swapScript.replacingOccurrences(of: "/usr/bin/open", with: "/usr/bin/true")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path, "2147483647", source.path, destination.path]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        precondition((process.terminationStatus == 0) == !missingSource)
        let marker = try String(contentsOf: destination.appendingPathComponent("marker"), encoding: .utf8)
        precondition(marker == (missingSource ? "old" : "new"))
    }
}
