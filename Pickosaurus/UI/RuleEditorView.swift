import SwiftUI

struct RuleEditorView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var name: String
    @State private var enabled: Bool
    @State private var conditions: [EditableRuleCondition]
    @State private var matchMode: RuleMatchMode
    @State private var usesApplication: Bool
    @State private var selectedApplicationId: String
    @State private var selectedBrowser: BrowserKind
    @State private var showDeleteConfirmation = false
    @State private var operationError: String?
    @State private var draftID: UUID

    private let existingID: UUID?
    private let existingPriority: Int?
    private let onSave: (RoutingRule) throws -> Void
    private let onClose: () -> Void

    init(rule: RoutingRule?, onClose: @escaping () -> Void, onSave: @escaping (RoutingRule) throws -> Void) {
        self.onClose = onClose
        existingID = rule?.id
        existingPriority = rule?.priority
        _draftID = State(initialValue: rule?.id ?? UUID())
        _name = State(initialValue: rule?.name ?? "")
        _enabled = State(initialValue: rule?.enabled ?? true)
        _matchMode = State(initialValue: rule?.matchMode ?? .any)
        let matchers = rule?.matchers ?? []
        _conditions = State(initialValue: (matchers.isEmpty ? [RuleMatcher(kind: .urlContains, value: "")] : matchers)
            .map { EditableRuleCondition(matcher: $0) })
        _usesApplication = State(initialValue: rule?.target.applicationBundleIdentifier != nil)
        _selectedApplicationId = State(initialValue: rule?.target.applicationBundleIdentifier ?? "")
        _selectedBrowser = State(initialValue: rule?.target.browser ?? .firefox)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: existingID == nil ? "plus.circle.fill" : "pencil.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(existingID == nil ? "Add Rule" : "Edit Rule")
                        .font(.title2.weight(.bold))
                    Text("Define when this rule matches and where links open.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: $enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider()

            GeometryReader { viewport in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        rulePreview
                        if let conflict = draftConflict {
                            RuleConflictNotice(
                                conflict: conflict,
                                earlierDestination: settingsStore.destination(for: conflict.earlierRule.target)?.displayName
                                    ?? settingsStore.destinationLabel(for: conflict.earlierRule.target)
                            )
                            .padding(14)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }

                        editorSection(title: "Name", subtitle: "A clear label for this rule.", icon: "tag") {
                            TextField("e.g. Work links → Firefox", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        editorSection(title: "Match conditions", subtitle: matchMode.explanation, icon: "text.magnifyingglass") {
                            Button {
                                HelpWindowController.ruleMatching.show()
                            } label: {
                                Label("Matching help", systemImage: "questionmark.circle")
                            }
                            .buttonStyle(.link)

                            Picker("Match mode", selection: $matchMode) {
                                ForEach(RuleMatchMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            ForEach($conditions) { $condition in
                                if condition.id != conditions.first?.id {
                                    Text(matchMode.conjunction)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                MatchConditionRow(
                                    matcher: $condition.matcher,
                                    number: (conditions.firstIndex { $0.id == condition.id } ?? 0) + 1,
                                    canRemove: conditions.count > 1,
                                    onRemove: { conditions.removeAll { $0.id == condition.id } }
                                )
                            }

                            Button {
                                conditions.append(EditableRuleCondition(matcher: RuleMatcher(kind: .urlContains, value: "")))
                            } label: {
                                Label("Add Condition", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                        }

                        editorSection(title: "Open in", subtitle: "Choose a browser or application for matched links.", icon: "arrow.up.forward.app") {
                            Picker("Destination type", selection: $usesApplication) {
                                Text("Browser").tag(false)
                                Text("Application").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: usesApplication) { _, enabled in
                                if enabled && selectedApplicationId.isEmpty {
                                    selectedApplicationId = settingsStore.enabledApplications.first?.id ?? ""
                                }
                            }
                            if usesApplication {
                                Picker("Application", selection: $selectedApplicationId) {
                                    Text("Choose application…").tag("")
                                    ForEach(settingsStore.enabledApplications) { app in
                                        Text(app.name).tag(app.id)
                                    }
                                    if !selectedApplicationId.isEmpty && !settingsStore.enabledApplications.contains(where: { $0.id == selectedApplicationId }) {
                                        Text("Unavailable application").tag(selectedApplicationId)
                                    }
                                }
                                Text("Add or enable destinations in Settings → Applications.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Picker("Browser", selection: $selectedBrowser) {
                                    ForEach(BrowserKind.allCases) { browser in
                                        Text(browser.displayName).tag(browser)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if !settingsStore.isAvailable(selectedTarget) {
                                    Label("Install or enable this browser in Settings → Browsers.", systemImage: "exclamationmark.triangle")
                                        .font(.caption).foregroundStyle(.orange)
                                }

                            }
                        }
                    }
                    // Native controls must stay within the viewport, even if their
                    // intrinsic width changes on a new macOS release.
                    .frame(width: max(0, viewport.size.width - 48), alignment: .leading)
                    .padding(24)
                }
            }

            Divider()

            HStack {
                if existingID != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Rule") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 480, idealWidth: 620, maxWidth: .infinity,
               minHeight: 380, idealHeight: 680, maxHeight: .infinity)
        .alert("Couldn’t Save Rule", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK", role: .cancel) { operationError = nil }
        } message: { Text(operationError ?? "") }
        .confirmationDialog(
            "Delete “\(name)”?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Rule", role: .destructive) {
                do {
                    if let existingID { try settingsStore.deleteRule(id: existingID) }
                    onClose()
                } catch { operationError = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This rule will be permanently removed. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var rulePreview: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WHEN")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                Text(conditionSummary)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 4) {
                Text("OPEN IN")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                if usesApplication, let app = settingsStore.settings.application(for: selectedTarget) {
                    HStack(spacing: 6) {
                        ApplicationIconView(application: app, size: 16)
                        Text(app.name).font(.caption.weight(.medium))
                    }
                } else if let destination = selectedDestination {
                    HStack(spacing: 6) {
                        BrowserIconView(browser: destination.browser, size: 16)
                        Text(destination.displayName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                } else {
                    Text("\(selectedBrowser.displayName) · …")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func editorSection<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private var selectedDestination: BrowserDestination? {
        guard !usesApplication else { return nil }
        return settingsStore.browsers(for: selectedBrowser).first
    }

    private var selectedTarget: RouteTarget {
        usesApplication ? RouteTarget(applicationBundleIdentifier: selectedApplicationId)
            : RouteTarget(browser: selectedBrowser)
    }

    private var conditionSummary: String {
        if conditions.count > 1 {
            return matchMode == .any ? "Any of \(conditions.count) conditions" : "All \(conditions.count) conditions"
        }
        guard let matcher = conditions.first?.matcher, matcher.isValid else { return "…" }
        return matcher.summary
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !conditions.isEmpty && conditions.allSatisfy { $0.matcher.isValid }
            && settingsStore.isAvailable(selectedTarget)
    }

    private var draftConflict: RuleConflict? {
        // Incomplete conditions are not diagnosed while the user is typing.
        guard !usesApplication || !selectedApplicationId.isEmpty else { return nil }
        let draft = RoutingRule(id: draftID, name: name, enabled: enabled,
                                priority: existingPriority ?? 0,
                                matchers: conditions.map(\.matcher), matchMode: matchMode,
                                target: selectedTarget)
        return RuleConflictAnalyzer().conflict(for: draft, in: settingsStore.settings)
    }

    private func save() {
        guard canSave else { return }
        let rule = RoutingRule(
            id: draftID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            enabled: enabled,
            priority: existingPriority ?? 0,
            matchers: conditions.map {
                RuleMatcher(kind: $0.matcher.kind, value: $0.matcher.normalizedValue, isNegated: $0.matcher.isNegated,
                            applicationName: $0.matcher.applicationName)
            },
            matchMode: matchMode,
            target: selectedTarget
        )
        do {
            try onSave(rule)
            onClose()
        } catch { operationError = error.localizedDescription }
    }
}

private struct EditableRuleCondition: Identifiable {
    let id = UUID()
    var matcher: RuleMatcher
}

private struct MatchConditionRow: View {
    @Binding var matcher: RuleMatcher
    let number: Int
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Condition \(number) match type", selection: $matcher.kind) {
                    ForEach(RuleMatcherKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                .onChange(of: matcher.kind) { old, new in
                    if old == .sourceApplication || new == .sourceApplication {
                        matcher.value = ""
                        matcher.applicationName = nil
                    }
                }

                Toggle("NOT", isOn: $matcher.isNegated)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                    .help("Invert this condition: match links that do not satisfy it.")
                    .accessibilityLabel("Negate condition \(number)")

                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!canRemove)
                .help("Remove condition")
                .accessibilityLabel("Remove condition \(number)")
            }
            if matcher.kind == .sourceApplication {
                SourceApplicationPicker(bundleIdentifier: $matcher.value, savedName: matcher.applicationName) { app in
                    matcher.applicationName = app.name
                }
            } else {
                TextField(placeholder, text: $matcher.value)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Condition \(number) value")
            }
            if !matcher.value.isEmpty, let message = matcher.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var placeholder: String {
        switch matcher.kind {
        case .urlContains: return "e.g. r2o"
        case .hostEquals: return "e.g. github.com"
        case .hostSuffix: return "e.g. .company.com"
        case .pathEquals: return "e.g. /dashboard"
        case .pathPrefix: return "e.g. /work/"
        case .pathContains: return "e.g. /invoices/"
        case .urlRegex: return #"e.g. ^https://example\.com/work/"#
        case .sourceApplication: return "Choose Application…"
        }
    }
}
