import SwiftUI

struct RuleTesterView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var urlText = ""
    @State private var result: RuleTestResult?
    @State private var validationError: String?
    @State private var sourceApp = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Rule tester", systemImage: "testtube.2")
                    .font(.headline)
                Spacer()
                Button {
                    HelpWindowController.ruleMatching.show()
                } label: {
                    Label("Matching help", systemImage: "questionmark.circle")
                }
                .buttonStyle(.link)
            }
            HStack(spacing: 10) {
                TextField("https://example.com/work/", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("URL to test")
                    .onSubmit(testRule)
                Button("Test Rule", action: testRule)
                    .buttonStyle(.borderedProminent)
            }
            HStack(spacing: 10) {
                Text("Source application").font(.caption).foregroundStyle(.secondary)
                SourceApplicationPicker(bundleIdentifier: $sourceApp, emptyTitle: "Unknown / not provided")
                    .frame(maxWidth: 280)
                if !sourceApp.isEmpty {
                    Button { sourceApp = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear source application")
                        .help("Test with an unknown source application.")
                }
                Spacer(minLength: 0)
            }
            if let validationError {
                Label(validationError, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let result {
                HStack(alignment: .top, spacing: 10) {
                    if let app = result.application {
                        ApplicationIconView(application: app, size: 32)
                    } else if let destination = result.destination {
                        BrowserIconView(browser: destination.browser, size: 32)
                    } else {
                        Image(systemName: result.isWarning ? "exclamationmark.triangle" : "rectangle.grid.2x2")
                            .foregroundStyle(result.isWarning ? Color.orange : Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title).font(.subheadline.weight(.semibold))
                        if let app = result.application {
                            Text(app.name).font(.body.weight(.semibold))
                        } else if let destination = result.destination {
                            Text(destination.displayName)
                                .font(.body.weight(.semibold))
                        }
                        Text(result.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            } else if validationError == nil {
                Text("Test saved rules and fallback behavior without opening the link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: urlText) { _, _ in clearResult() }
        .onChange(of: sourceApp) { _, _ in clearResult() }
        .onReceive(settingsStore.$settings) { _ in clearResult() }
        .onReceive(settingsStore.$browsers) { _ in clearResult() }
    }

    private func testRule() {
        guard let url = RuleTester.parseURL(urlText) else {
            result = nil
            validationError = "Enter a valid URL starting with http:// or https://."
            return
        }
        validationError = nil
        result = RuleTester.test(url: url, store: settingsStore, sourceApp: sourceApp.isEmpty ? nil : sourceApp)
    }

    private func clearResult() {
        result = nil
        validationError = nil
    }
}
