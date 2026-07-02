import SwiftUI

/// HUD theme params flowing from ``NexusGameGeneratorView`` → ``GamePlayView`` live session.
struct NexusGeneratorHudTheme: Sendable, Equatable {
    let primaryHex: String
    let accentHex: String
    let badgeLabel: String

    init(primaryHex: String, accentHex: String, badgeLabel: String) {
        self.primaryHex = primaryHex
        self.accentHex = accentHex
        self.badgeLabel = badgeLabel
    }

    init?(from spec: NexusGameplayEngine.GeneratedGameSpec?) {
        guard let spec,
              let primary = spec.hudPrimaryColor,
              let accent = spec.hudAccentColor else {
            return nil
        }
        self.primaryHex = primary
        self.accentHex = accent
        self.badgeLabel = spec.hudBadgeLabel ?? "NEXUS"
    }

    var primaryColor: Color {
        Color(hex: primaryHex) ?? Theme.brandCyan
    }

    var accentColor: Color {
        Color(hex: accentHex) ?? Theme.elitePurple
    }
}
