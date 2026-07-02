import SwiftUI

// MARK: - Metric specs (icon + short label)

struct FELHudMetricSpec: Equatable {
    let icon: String
    let label: String
}

enum FELHudMetrics {
    static func playerColumn(
        gameModeId: GameModeId,
        usesGolf: Bool,
        usesSoccer: Bool,
        usesBaseball: Bool,
        usesKarateH2H: Bool,
        usesKarateEndless: Bool,
        usesCarnival: Bool
    ) -> FELHudMetricSpec {
        if usesGolf { return .init(icon: "flag.fill", label: "STR") }
        if usesSoccer { return .init(icon: "soccerball", label: "GOL") }
        if usesBaseball { return .init(icon: "baseball.fill", label: "RUN") }
        if usesKarateH2H { return .init(icon: "heart.fill", label: "YOU") }
        if usesKarateEndless { return .init(icon: "star.fill", label: "PTS") }
        if usesCarnival { return .init(icon: "star.fill", label: "PTS") }
        switch gameModeId {
        case .brainBrawl: return .init(icon: "brain.head.profile.fill", label: "YOU")
        case .whoSceneIt: return .init(icon: "film.fill", label: "YOU")
        default: return .init(icon: "person.fill", label: "YOU")
        }
    }

    static func opponentColumn(
        gameModeId: GameModeId,
        usesGolf: Bool,
        usesSoccer: Bool,
        usesBaseball: Bool,
        usesKarateH2H: Bool,
        usesKarateEndless: Bool,
        usesCarnival: Bool
    ) -> FELHudMetricSpec {
        if usesGolf { return .init(icon: "target", label: "PAR") }
        if usesSoccer { return .init(icon: "soccerball", label: "GOL") }
        if usesBaseball { return .init(icon: "baseball.fill", label: "OPP") }
        if usesKarateH2H { return .init(icon: "heart.slash.fill", label: "FOE") }
        if usesKarateEndless { return .init(icon: "figure.martial.arts", label: "FOE") }
        if usesCarnival { return .init(icon: "person.2.fill", label: "OPP") }
        switch gameModeId {
        case .brainBrawl: return .init(icon: "cpu.fill", label: "AI")
        case .whoSceneIt: return .init(icon: "person.2.fill", label: "AI")
        default: return .init(icon: "person.fill", label: "OPP")
        }
    }
}

// MARK: - Primitives

struct FELHudIconLabel: View {
    let spec: FELHudMetricSpec
    var accent: Color = .secondary
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: spec.icon)
                .font(.system(size: size - 1, weight: .bold))
            Text(spec.label)
                .font(FELTypography.mono(size, weight: .bold))
        }
        .foregroundStyle(accent.opacity(0.85))
    }
}

struct FELHudChip: View {
    let icon: String
    let label: String
    let value: String
    var accent: Color = Theme.brandCyan
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(label)
                .font(FELTypography.mono(7, weight: .bold))
            Text(value)
                .font(FELTypography.mono(8, weight: .black))
        }
        .foregroundStyle(highlight ? accent : accent.opacity(0.9))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(accent.opacity(highlight ? 0.18 : 0.1))
                .overlay {
                    Capsule()
                        .strokeBorder(accent.opacity(0.25), lineWidth: 0.5)
                }
        }
    }
}

struct FELHudGlassBackground: View {
    var accent: Color = Theme.brandCyan

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [accent.opacity(0.06), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Outcome sport strip

struct FELOutcomeSportHudStrip: View {
    let snapshot: NexusHUDSnapshot
    let accent: Color
    var karateH2H: Bool = false
    var showPulseBonus: Bool = false
    var lastPulsePoints: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            FlowLayout(spacing: 4) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    FELHudChip(
                        icon: chip.icon,
                        label: chip.label,
                        value: chip.value,
                        accent: chip.accent,
                        highlight: chip.highlight
                    )
                }
            }

            if karateH2H, !snapshot.outcomeSportLastAction.isEmpty {
                Text(FELPremiumCopy.humanizeOutcomeSportAction(snapshot.outcomeSportLastAction).uppercased())
                    .font(FELTypography.mono(7, weight: .black))
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityIdentifier("KarateH2HLastAction")
            } else if showPulseBonus {
                HStack(spacing: 4) {
                    if snapshot.outcomeSportStreak > 0 {
                        FELHudChip(
                            icon: "flame.fill",
                            label: "STR",
                            value: "×\(snapshot.outcomeSportStreak)",
                            accent: .yellow,
                            highlight: true
                        )
                    }
                    if lastPulsePoints > 0 {
                        FELHudChip(
                            icon: "plus.circle.fill",
                            label: "PTS",
                            value: "+\(lastPulsePoints)",
                            accent: Theme.brandCyan
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("OutcomeSportStatusLine")
    }

    private struct ChipData {
        let icon: String
        let label: String
        let value: String
        let accent: Color
        let highlight: Bool
    }

    private var chips: [ChipData] {
        let modeKey = snapshot.outcomeSportModeId.isEmpty ? snapshot.modeId : snapshot.outcomeSportModeId
        let p = snapshot.outcomeSportPlayerMetric
        let o = snapshot.outcomeSportOpponentMetric

        switch modeKey {
        case "baseball":
            let inn = max(snapshot.outcomeSportInning, 1)
            return [
                ChipData(icon: "clock.fill", label: "INN", value: "\(inn)", accent: accent, highlight: false),
                ChipData(icon: "baseball.fill", label: "RUN", value: "\(p)-\(o)", accent: accent, highlight: false)
            ]
        case "football":
            return [
                ChipData(icon: "football.fill", label: "TD", value: "\(p)-\(o)", accent: accent, highlight: false),
                ChipData(icon: "star.fill", label: "PTS", value: "\(Int(snapshot.playerScore))-\(Int(snapshot.opponentScore))", accent: Theme.brandCyan, highlight: false)
            ]
        case "soccer":
            let target = snapshot.outcomeSportWinTarget > 0 ? snapshot.outcomeSportWinTarget : 5
            let round = snapshot.outcomeSportPenaltyRound > 0
                ? snapshot.outcomeSportPenaltyRound
                : max(1, p + o)
            return [
                ChipData(icon: "soccerball", label: "PK", value: "R\(round)", accent: accent, highlight: false),
                ChipData(icon: "soccerball", label: "GOL", value: "\(p)-\(o)", accent: accent, highlight: false),
                ChipData(icon: "flag.checkered", label: "WIN", value: "\(target)", accent: Theme.brandCyan, highlight: false)
            ]
        case "golf":
            let par = snapshot.outcomeSportCoursePar > 0 ? snapshot.outcomeSportCoursePar : 36
            let hole = min(max(snapshot.outcomeSportHolesPlayed + 1, 1), 9)
            return [
                ChipData(icon: "flag.fill", label: "HOLE", value: "\(hole)/9", accent: accent, highlight: false),
                ChipData(icon: "figure.golf", label: "STR", value: "\(p)/\(par)", accent: accent, highlight: false)
            ]
        case "tennis":
            return [
                ChipData(icon: "sportscourt.fill", label: "SET", value: "\(snapshot.outcomeSportPlayerSets)-\(snapshot.outcomeSportOpponentSets)", accent: accent, highlight: false),
                ChipData(icon: "tennisball.fill", label: "G", value: "\(p)-\(o)", accent: accent, highlight: false)
            ]
        case "volleyball":
            return [
                ChipData(icon: "volleyball.fill", label: "RALLY", value: "\(p)-\(o)", accent: accent, highlight: false),
                ChipData(icon: "flag.checkered", label: "WIN", value: "25+2", accent: Theme.brandCyan, highlight: false)
            ]
        case "basketball_3v3":
            var result: [ChipData] = []
            if snapshot.outcomeSportHotStreak {
                result.append(ChipData(icon: "flame.fill", label: "HOT", value: "ON", accent: .yellow, highlight: true))
            }
            if snapshot.outcomeSportLastAction == "three_pointer" {
                result.append(ChipData(icon: "3.circle.fill", label: "3PT", value: "\(p)-\(o)", accent: accent, highlight: true))
            } else {
                result.append(ChipData(icon: "basketball.fill", label: "PTS", value: "\(p)-\(o)", accent: accent, highlight: false))
            }
            return result
        case "karate_h2h":
            return [
                ChipData(icon: "heart.fill", label: "YOU", value: "\(Int(snapshot.playerScore))", accent: .orange, highlight: false),
                ChipData(icon: "heart.slash.fill", label: "FOE", value: "\(Int(snapshot.opponentScore))", accent: .orange, highlight: false)
            ]
        default:
            if !snapshot.outcomeSportLastAction.isEmpty {
                let label = FELPremiumCopy.humanizeOutcomeSportAction(snapshot.outcomeSportLastAction)
                return [ChipData(icon: "bolt.fill", label: "ACT", value: label.uppercased(), accent: accent, highlight: false)]
            }
            return []
        }
    }
}

// MARK: - Dojo Breach wave / co-op

struct FELDojoBreachHudStrip: View {
    let snapshot: NexusHUDSnapshot
    var localFallback: Bool = false
    var roundNumber: Int = 1
    var coopPlayerCount: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                if localFallback {
                    FELHudChip(icon: "waveform.path", label: "WAVE", value: "\(min(roundNumber, 10))/10", accent: .orange)
                    FELHudChip(icon: "person.2.fill", label: "CO-OP", value: "×\(coopPlayerCount)", accent: Theme.brandCyan)
                } else {
                    FELHudChip(
                        icon: "waveform.path",
                        label: "WAVE",
                        value: "\(max(snapshot.karateWave, 1))/\(max(snapshot.karateTargetWave, 10))",
                        accent: .orange,
                        highlight: snapshot.karateWaveState == "combat"
                    )
                    FELHudChip(
                        icon: "figure.martial.arts",
                        label: "FOE",
                        value: "×\(max(snapshot.karateOpponentsAlive, 0))",
                        accent: .orange,
                        highlight: snapshot.karateOpponentsAlive <= 2
                    )
                    if snapshot.karatePlayerCount > 1 {
                        FELHudChip(
                            icon: "person.2.fill",
                            label: "CO-OP",
                            value: "×\(snapshot.karatePlayerCount)",
                            accent: Theme.brandCyan
                        )
                    }
                }
            }

            if !localFallback {
                if snapshot.karatePlayerCount > 1 {
                    HStack(spacing: 3) {
                        ForEach(0..<snapshot.karatePlayerCount, id: \.self) { slot in
                            let hp = slot < snapshot.karatePlayerHPs.count ? snapshot.karatePlayerHPs[slot] : 0
                            coOpHPBadge(slot: slot, hp: hp, active: slot == snapshot.karateActivePlayer)
                        }
                    }
                } else {
                    coOpHPBadge(slot: 0, hp: max(snapshot.karatePlayerHP, 100), active: true)
                }

                if snapshot.karateWaveState == "intermission" {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 7, weight: .bold))
                        Text("SHRINE")
                            .font(FELTypography.mono(7, weight: .black))
                    }
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.yellow.opacity(0.12)))
                }
            }
        }
    }

    @ViewBuilder
    private func coOpHPBadge(slot: Int, hp: Double, active: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.system(size: 6, weight: .bold))
            Text("P\(slot + 1)")
                .font(FELTypography.mono(6, weight: .black))
            Text("\(Int(hp))")
                .font(FELTypography.mono(7, weight: .bold))
        }
        .foregroundStyle(active ? Color.orange : Color.white.opacity(0.7))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background {
            Capsule()
                .fill(active ? Color.orange.opacity(0.28) : Color.white.opacity(0.08))
                .overlay {
                    Capsule()
                        .strokeBorder(active ? Color.orange.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Brain / cognitive strip

struct FELBrainHudStrip: View {
    let snapshot: NexusHUDSnapshot
    let modeId: GameModeId

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                FELHudChip(
                    icon: modeId == .whoSceneIt ? "film.fill" : "brain.head.profile.fill",
                    label: modeId == .whoSceneIt ? "SCN" : "YOU",
                    value: "\(snapshot.brainPlayerCorrect)/\(winTarget)",
                    accent: Theme.elitePurple,
                    highlight: true
                )
                FELHudChip(
                    icon: "cpu.fill",
                    label: "AI",
                    value: "\(snapshot.brainOpponentCorrect)",
                    accent: Theme.brandCyan
                )
            }
            HStack(spacing: 4) {
                if snapshot.cognitiveStreak > 1 {
                    FELHudChip(
                        icon: "flame.fill",
                        label: "STR",
                        value: "×\(snapshot.cognitiveStreak)",
                        accent: .yellow,
                        highlight: true
                    )
                }
                FELHudChip(
                    icon: "lightbulb.fill",
                    label: "IQ",
                    value: String(format: "%.0f", snapshot.cognitiveScore),
                    accent: Theme.elitePurple.opacity(0.85)
                )
                if modeId == .whoSceneIt, snapshot.scenePlayerHasBuzz {
                    FELHudChip(icon: "bell.fill", label: "BUZZ", value: "ON", accent: .green, highlight: true)
                }
            }
        }
    }

    private var winTarget: Int {
        if modeId == .whoSceneIt {
            return max(snapshot.cognitiveWinTarget, 7)
        }
        return max(snapshot.cognitiveWinTarget, 10)
    }
}

// MARK: - Flow layout (chip wrap)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
