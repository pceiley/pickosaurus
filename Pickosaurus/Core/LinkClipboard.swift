import AppKit

enum LinkClipboard {
    @MainActor
    static func copy(_ url: URL, to pasteboard: NSPasteboard = .general) throws {
        guard WebURL.isAllowed(url) else { throw PickosaurusError.unsupportedURL }
        pasteboard.clearContents()
        guard pasteboard.setString(url.absoluteString, forType: .string) else { throw CopyError.unavailable }
    }

    private enum CopyError: LocalizedError {
        case unavailable
        var errorDescription: String? { "The link couldn’t be copied. Try again." }
    }
}
