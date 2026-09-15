import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case rules
    case browsers
    case applications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .rules: return "Rules"
        case .browsers: return "Browsers"
        case .applications: return "Applications"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .rules: return "arrow.triangle.branch"
        case .browsers: return "globe"
        case .applications: return "app.badge"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Default behavior and browser status"
        case .rules: return "Automatic link routing"
        case .browsers: return "Installed browsers"
        case .applications: return "Other link destinations"
        }
    }
}

struct SettingsPageHeader: View {
    let title: String
    let subtitle: String
    var icon: String?
    var action: (() -> Void)?
    var actionTitle: String?
    var actionIcon: String?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let action, let actionTitle {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionIcon ?? "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct StatusBanner: View {
    enum Style {
        case success, warning

        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.seal.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    let style: Style
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: style.icon)
                .font(.title2)
                .foregroundStyle(style.color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(style.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style.color.opacity(0.18), lineWidth: 1)
        }
    }
}

struct SettingsDetailScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    var icon: String?
    var action: (() -> Void)?
    var actionTitle: String?
    var actionIcon: String?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    action: action,
                    actionTitle: actionTitle,
                    actionIcon: actionIcon
                )
                content
            }
            .padding(28)
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
