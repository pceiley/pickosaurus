import SwiftUI
import ServiceManagement

struct LoginItemSettingsCard: View {
    @StateObject private var loginItem = LoginItemController()

    var body: some View {
        SettingsCard(title: "Startup", subtitle: "Keep Pickosaurus ready for the first link of the day.") {
            Toggle("Start at login", isOn: Binding(get: { loginItem.isRequested }, set: { enabled in
                Task { await loginItem.setEnabled(enabled) }
            }))
            .disabled(loginItem.isChanging)
            if loginItem.status == .requiresApproval {
                Text("Allow Pickosaurus in macOS Login Items to finish enabling this option.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            } else {
                Text(loginItem.status == .enabled
                     ? "Pickosaurus will open in the menu bar when you sign in."
                     : "Turn this on after keeping the app in a permanent location, such as Applications.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in loginItem.refresh() }
        .alert("Couldn’t Change Login Item", isPresented: Binding(get: { loginItem.errorMessage != nil }, set: { if !$0 { loginItem.errorMessage = nil } })) {
            Button("OK", role: .cancel) { loginItem.errorMessage = nil }
        } message: { Text(loginItem.errorMessage ?? "") }
    }
}
