import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var updateController: UpdateController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pickosaurus").font(.headline).padding(.horizontal, 8)
            if settingsStore.settings.alwaysShowPicker {
                Text("Choose a destination for every link.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("When no rule matches")
                        .font(.caption).foregroundStyle(.secondary)
                    FallbackDestinationPicker()
                        .labelsHidden()
                }
                .padding(.horizontal, 8)
            }
            Divider()
            actionRows
            Divider()
            MenuRow(title: "Quit Pickosaurus", systemImage: "power", role: .destructive) { NSApplication.shared.terminate(nil) }
        }
        .padding(10)
        .frame(width: 268)
        .onAppear { appState.refreshDefaultBrowserStatus() }
    }

    @ViewBuilder
    private var actionRows: some View {
        if appState.isDefaultBrowser {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .frame(width: 18)
                Text("Default browser")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        } else {
            MenuRow(title: "Set as Default Browser…", systemImage: "star") {
                appState.registerAsDefaultBrowser()
                dismiss()
            }
        }

        MenuRow(title: "Refresh Browsers", systemImage: "arrow.clockwise") {
            settingsStore.reloadBrowsers()
            dismiss()
        }

        MenuRow(title: "Settings…", systemImage: "gearshape") {
            dismiss()
            SettingsWindowController.shared.show(
                settingsStore: settingsStore,
                appState: appState
            )
        }

        MenuRow(title: "Check for Updates…", systemImage: "arrow.down.circle") {
            dismiss()
            updateController.checkForUpdates(silent: false)
        }

        MenuRow(title: "FAQ", systemImage: "questionmark.circle") {
            dismiss()
            HelpWindowController.faq.show()
        }

        MenuRow(title: "About", systemImage: "info.circle") {
            dismiss()
            AboutWindowController.shared.show()
        }
    }

}

private struct MenuRow: View {
    let title: String
    var systemImage: String
    var role: ButtonRole?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(role == .destructive ? Color.red : Color.primary)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(role == .destructive ? Color.red : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
