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

        precondition(UpdateConfiguration.isValidFeedURL("https://github.com/example/pickosaurus/releases/latest/download/appcast.xml"))
        for value in [nil, "", "http://github.com/example/pickosaurus/releases/latest/download/appcast.xml", "https://evil.test/example/pickosaurus/releases/latest/download/appcast.xml", "https://github.com@example.test/example/pickosaurus/releases/latest/download/appcast.xml", "https://github.com/example/pickosaurus/releases/latest/download/appcast.xml?token=secret"] {
            precondition(!UpdateConfiguration.isValidFeedURL(value))
        }
        precondition(UpdateConfiguration.isValidPublicKey("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="))
        for value in [nil, "", "not-base64", "AAAA"] {
            precondition(!UpdateConfiguration.isValidPublicKey(value))
        }
        print("PASS: Sparkle updates fail closed unless the HTTPS feed and EdDSA public key are configured")
    }
}
