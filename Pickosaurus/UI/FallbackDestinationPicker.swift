import SwiftUI

/// Shared by General settings and the menu bar so both edit the same choice.
struct FallbackDestinationPicker: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var errorMessage: String?

    var body: some View {
        Picker("When no rule matches", selection: Binding(
            get: { settingsStore.fallbackDestination },
            set: { target in
                do { try settingsStore.setFallbackDestination(target) }
                catch { errorMessage = error.localizedDescription }
            }
        )) {
            Text("Show picker").tag(nil as RouteTarget?)
            Divider()
            if let target = settingsStore.fallbackDestination, !settingsStore.isAvailable(target) {
                Text("\(settingsStore.destinationLabel(for: target)) (unavailable)")
                    .tag(Optional(target))
            }
            ForEach(settingsStore.enabledBrowsers) { destination in
                Text(destination.displayName).tag(Optional(destination.target))
            }
            ForEach(settingsStore.enabledApplications) { application in
                Text(application.name).tag(Optional(application.target))
            }
        }
        .pickerStyle(.menu)
        .alert("Couldn’t Update Link Handling", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
