import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var appState: AppState
    @State private var selection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 232)

            Divider()

            Group {
                switch selection {
                case .general:
                    GeneralSettingsTab()
                case .rules:
                    RulesListView(onShowLinkSettings: { selection = .general })
                case .browsers:
                    BrowsersSettingsTab()
                case .applications:
                    ApplicationsSettingsView()
                }
            }
            .environmentObject(settingsStore)
            .environmentObject(appState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases) { section in
                    SidebarRow(
                        section: section,
                        isSelected: selection == section,
                        isPaused: section == .rules && settingsStore.settings.alwaysShowPicker,
                        action: { selection = section }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer(minLength: 0)

            sidebarFooter
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text("Pickosaurus")
                    .font(.headline)
                Text("v\(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.isDefaultBrowser ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(appState.isDefaultBrowser ? "Default browser" : "Not default")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

private struct SidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let isPaused: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(isPaused ? "Paused · Always show picker" : section.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.07) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct GeneralSettingsTab: View {
    @State private var operationError: String?
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsDetailScaffold(title: "General", subtitle: "Control how Pickosaurus handles links.", icon: "gearshape.fill") {
            SettingsCard(title: "Link handling", subtitle: "Show the picker for every link, or let rules choose a destination.") {
                Toggle("Always show picker", isOn: Binding(
                    get: { settingsStore.settings.alwaysShowPicker },
                    set: { value in
                        do { try settingsStore.updateSettings { $0.alwaysShowPicker = value } }
                        catch { operationError = error.localizedDescription }
                    }
                ))
                Text(settingsStore.settings.alwaysShowPicker
                     ? "Rules and the fallback action are paused. Your settings are kept for when you turn this off."
                     : "Rules run first. The fallback action below applies when no rule matches.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                FallbackDestinationPicker()
                    .disabled(settingsStore.settings.alwaysShowPicker)
                    .opacity(settingsStore.settings.alwaysShowPicker ? 0.5 : 1)
            }
            LoginItemSettingsCard()
            if appState.isDefaultBrowser {
                StatusBanner(style: .success, title: "Default browser active", message: "Links from other apps are routed through Pickosaurus.")
            } else {
                StatusBanner(style: .warning, title: "Not the default browser", message: "Set Pickosaurus as default to handle links from other apps.", actionTitle: "Make Default", action: appState.registerAsDefaultBrowser)
            }
        }
        .alert("Couldn’t Save Settings", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK", role: .cancel) { operationError = nil }
        } message: { Text(operationError ?? "") }
    }
}

private struct BrowsersSettingsTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var errorMessage: String?

    var body: some View {
        SettingsDetailScaffold(title: "Browsers", subtitle: "Choose which browsers can open links.", icon: "globe",
            action: { settingsStore.reloadBrowsers() }, actionTitle: "Refresh", actionIcon: "arrow.clockwise") {
            Text("Each browser chooses its own current or default profile. Disabled browsers are hidden from the picker and skipped by rules.")
                .font(.subheadline).foregroundStyle(.secondary)
            if settingsStore.browsers.isEmpty {
                ContentUnavailableView("No Browsers Found", systemImage: "globe", description: Text("Install a browser, then refresh."))
            }
            if !settingsStore.browsers.isEmpty {
                SettingsCard(title: "Installed browsers", subtitle: "Click a browser or its key to change the shortcut. Use Disable Shortcut to leave it unassigned.") {
                    VStack(spacing: 0) {
                        ForEach(Array(settingsStore.browsers.enumerated()), id: \.element.id) { index, destination in
                            HStack(spacing: 20) {
                                ShortcutRecorder(name: destination.displayName,
                                    shortcut: settingsStore.settings.browserShortcuts[destination.browser.rawValue],
                                    onChange: { key in
                                        do { try settingsStore.setBrowserShortcut(key, for: destination.browser) }
                                        catch { errorMessage = error.localizedDescription }
                                    }) {
                                    BrowserIconView(browser: destination.browser, size: 24)
                                    Text(destination.displayName)
                                        .font(.body.weight(.medium))
                                        .opacity(settingsStore.isBrowserEnabled(destination) ? 1 : 0.5)
                                }
                                Toggle("Enabled", isOn: Binding(get: { settingsStore.isBrowserEnabled(destination) }, set: { enabled in
                                    do { try settingsStore.setBrowserEnabled(enabled, for: destination) }
                                    catch { errorMessage = error.localizedDescription }
                                }))
                                .toggleStyle(.switch)
                                .fixedSize()
                                .accessibilityLabel("Enable \(destination.displayName)")
                            }
                            .padding(.vertical, 8)
                            if index < settingsStore.browsers.count - 1 { Divider() }
                        }
                    }
                }
            }

        }
        .alert("Couldn’t Update Browser", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

}
