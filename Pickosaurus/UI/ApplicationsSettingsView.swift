import SwiftUI
import UniformTypeIdentifiers

struct ApplicationsSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selection = ""
    @State private var errorMessage: String?

    var body: some View {
        SettingsDetailScaffold(title: "Applications", subtitle: "Open links in installed apps alongside your browsers.", icon: "app.badge") {
            SettingsCard(title: "Add an application", subtitle: "The app must support opening links. Zoom meeting invitations open directly in Zoom.") {
                HStack {
                    SourceApplicationPicker(bundleIdentifier: $selection, emptyTitle: "Search Applications…",
                                            accessibilityTitle: "Add destination application", onSelect: add)
                    Button("Browse…", action: browse)
                }
            }
            ForEach(settingsStore.settings.applications) { app in
                SettingsCard(title: app.name, subtitle: app.applicationURL == nil ? "Not found — add it again if it was moved or reinstalled." : nil) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ApplicationIconView(application: app, size: 28)
                            Toggle("Enabled", isOn: Binding(get: { app.enabled }, set: { value in
                                update(app) { $0.enabled = value }
                            })).toggleStyle(.switch)
                            Spacer()
                            ShortcutRecorder(name: app.name, shortcut: app.shortcut, onChange: { key in
                                update(app) { $0.shortcut = key }
                            }) {
                                Text("Picker key")
                            }
                            .frame(width: 170)
                            Button("Remove", role: .destructive) {
                                perform { try settingsStore.removeApplication(id: app.id) }
                            }
                        }
                        Text(app.isZoom
                             ? "Supports standard /j/ meeting invitations on Zoom domains, including meeting passcodes. Open personal-room, registration and sign-in pages in a browser."
                             : "Pickosaurus passes the original web link to this app. Link support depends on the application.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        if app.isZoom {
                            Button("Create Zoom meeting rule") { perform { try settingsStore.addZoomRule(for: app) } }
                                .disabled(settingsStore.settings.rules.contains { $0.target == app.target })
                            if settingsStore.settings.alwaysShowPicker {
                                Text("Rules are paused while Always show picker is on. You can still choose Zoom in the picker.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if settingsStore.settings.applications.isEmpty {
                Text("Add Zoom or another app above. It will appear in the picker and in rule destinations. You can also assign it a picker key.")
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Couldn’t Update Application", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func add(_ app: InstalledApplication) {
        perform { try settingsStore.addApplication(app) }
        selection = ""
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.title = "Add Application"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let app = InstalledApplication(url: url) else { errorMessage = "Choose a macOS application bundle."; return }
        add(app)
    }

    private func update(_ app: LinkApplication, _ change: (inout LinkApplication) -> Void) {
        var updated = app
        change(&updated)
        perform { try settingsStore.updateApplication(updated) }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }
}

struct ApplicationIconView: View {
    let application: LinkApplication
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let url = application.applicationURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            } else {
                Image(systemName: "app.dashed").resizable()
            }
        }
        .scaledToFit().frame(width: size, height: size)
    }
}
