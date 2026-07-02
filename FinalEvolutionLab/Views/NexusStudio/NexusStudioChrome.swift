import SwiftUI

// MARK: - Typography & cards

struct NexusStudioSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
    }
}

struct NexusStudioPanelHeader: View {
    let title: String
    let accent: Color
    var previewLabel: String?
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                Spacer(minLength: 8)
                if let previewLabel {
                    FELPreviewLabel(text: previewLabel)
                }
            }
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct NexusStudioDarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.slateMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func nexusStudioCard() -> some View {
        padding(16)
            .background(Theme.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Connection & status pills

struct NexusStudioConnectionPill: View {
    enum Tone: Equatable {
        case connected
        case active
        case standby
        case offline

        var color: Color {
            switch self {
            case .connected: Theme.neonGreen
            case .active: Theme.brandCyan
            case .standby: Theme.elitePurple
            case .offline: Color.orange.opacity(0.85)
            }
        }

        var icon: String {
            switch self {
            case .connected: "checkmark.circle.fill"
            case .active: "dot.radiowaves.left.and.right"
            case .standby: "sparkles"
            case .offline: "wand.and.stars"
            }
        }
    }

    let tone: Tone
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: tone.icon)
                    .font(.caption2.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tone.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tone.color.opacity(0.12))
                    .overlay(Capsule().stroke(tone.color.opacity(0.28), lineWidth: 1))
            )

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct NexusStudioStatusPill: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "info.circle.fill")
                .font(.caption2.weight(.semibold))
            Text(message)
                .font(.caption)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(isError ? Color.orange.opacity(0.92) : Theme.brandCyan.opacity(0.92))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule()
                .fill((isError ? Color.orange : Theme.brandCyan).opacity(0.1))
                .overlay(
                    Capsule().stroke((isError ? Color.orange : Theme.brandCyan).opacity(0.22), lineWidth: 1)
                )
        )
    }
}

extension NexusAIStudioConfigService.ConnectionStatus {
    var pillTone: NexusStudioConnectionPill.Tone {
        switch self {
        case .connected: .connected
        case .checking: .active
        case .templateFallback: .offline
        case .unknown: .standby
        }
    }

    var pillTitle: String {
        switch self {
        case .connected: "AI connected"
        case .checking: "Connecting…"
        case .templateFallback: "Templates only"
        case .unknown: "Not verified"
        }
    }

    func pillDetail(config: NexusAIStudioConfigService) -> String? {
        switch self {
        case .connected:
            return "\(config.selectedModel) · \(config.apiKeySourceLabel)"
        case .checking:
            return "Checking your Creative AI connection"
        case .templateFallback(let reason):
            if reason.isEmpty || reason == "No API key" {
                return "Add an API key to unlock AI-assisted creation"
            }
            return reason
        case .unknown:
            if config.resolvedAPIKey() != nil {
                return "Run a connection test in Creative AI settings"
            }
            return "Works offline with built-in game templates"
        }
    }
}
