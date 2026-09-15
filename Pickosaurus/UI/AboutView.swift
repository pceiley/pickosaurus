import AppKit
import SwiftUI

struct AboutView: View {
    @State private var showingNotices = false
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 84, height: 84)

            VStack(spacing: 3) {
                Text("Pickosaurus")
                    .font(.title2.weight(.bold))
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("A simple, fast link picker for macOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.horizontal, 24)

            VStack(spacing: 6) {
                Text("Small by design. Private by default.")
                    .font(.subheadline)
                Text("Open links with minimal fuss and no unnecessary permissions. No analytics, tracking or data sent to the developer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Privacy policy…") { HelpWindowController.privacy.show() }
                Text("Open source · MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("License and notices…") { showingNotices = true }
                Text("Inspired by Browserino and Browserosaurus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        }
        .padding(28)
        .frame(width: 320)
        .sheet(isPresented: $showingNotices) {
            VStack(alignment: .leading, spacing: 16) {
                Text("License and notices").font(.title2.bold())
                ScrollView {
                    Text(notices).font(.system(.body, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("Done") { showingNotices = false }.keyboardShortcut(.cancelAction)
            }.padding(24).frame(width: 620, height: 480)
        }
    }

    private var notices: String {
        ["LICENSE", "NOTICES"].compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "txt")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }.joined(separator: "\n\n")
    }
}

@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "About Pickosaurus"
            newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
            newWindow.titlebarAppearsTransparent = true
            newWindow.isMovableByWindowBackground = true
            newWindow.center()
            newWindow.delegate = self
            newWindow.isReleasedWhenClosed = false
            window = newWindow
        }

        AppWindowPresentation.shared.show(window)
    }
}
