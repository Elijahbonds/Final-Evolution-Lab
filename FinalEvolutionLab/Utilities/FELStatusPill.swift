import SwiftUI

/// Premium lane / connection status pill for dashboard and chrome surfaces.
struct FELStatusPill: View {
    enum Style: Sendable {
        case live
        case connected
        case preview
        case offline
        case disabled

        var color: Color {
            switch self {
            case .live, .connected: Theme.neonGreen
            case .preview: .orange
            case .offline: .orange
            case .disabled: .secondary
            }
        }

        var dotColor: Color { color }
    }

    var text: String
    var style: Style
    var showDot: Bool = true
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 5) {
            if showDot {
                Circle()
                    .fill(style.dotColor)
                    .frame(width: compact ? 5 : 6, height: compact ? 5 : 6)
            }
            Text(text)
                .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                .foregroundStyle(style.color)
        }
        .padding(.horizontal, compact ? 7 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(
            Capsule()
                .fill(style.color.opacity(0.12))
                .overlay(Capsule().strokeBorder(style.color.opacity(0.28), lineWidth: 0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

/// Subtle connection indicator — replaces blocking PREVIEW banners when AI Studio is live.
struct FELConnectionDot: View {
    var color: Color
    var size: CGFloat = 7
    var accessibilityLabel: String

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(color.opacity(0.35), lineWidth: 1))
            .shadow(color: color.opacity(0.45), radius: 3)
            .accessibilityLabel(accessibilityLabel)
    }
}

/// Preview honesty: full banner when AI Studio offline; subtle dot when connected.
struct FELFeaturePreviewIndicator: View {
    var previewText: String
    var dotColor: Color = .orange

    var body: some View {
        if NexusAIStudioBootstrap.isConfigured {
            FELConnectionDot(color: dotColor, size: 6, accessibilityLabel: "Preview feature")
        } else {
            FELPreviewLabel(text: previewText)
        }
    }
}
