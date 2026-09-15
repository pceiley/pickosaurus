import AppKit
import SwiftUI

enum BrowserIconProvider {
    static func icon(for browser: BrowserKind, size: CGFloat = 20) -> NSImage {
        if let appURL = browser.installedAppURL {
            let image = NSWorkspace.shared.icon(forFile: appURL.path)
            image.size = NSSize(width: size, height: size)
            return image
        }
        return fallbackIcon(for: browser, size: size)
    }

    private static func fallbackIcon(for browser: BrowserKind, size: CGFloat) -> NSImage {
        // Identify installed applications using macOS; do not redistribute vendor artwork.
        if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: browser.displayName) {
            image.size = NSSize(width: size, height: size)
            return image
        }

        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.secondaryLabelColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        image.unlockFocus()
        return image
    }

}

struct BrowserIconView: View {
    let browser: BrowserKind
    var size: CGFloat = 20

    var body: some View {
        Image(nsImage: BrowserIconProvider.icon(for: browser, size: size))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
