import SwiftUI

/// Broadcast lower-third scoreboard composing OdometerScore + ShotClock +
/// PossessionIndicator over an FELHudGlassBackground. Restrained/premium:
/// home column | center cluster | away column.
struct BasketballScoreboard: View {
    enum Layout {
        case headToHead
        case threeVThree
    }

    var layout: Layout
    let homeScore: Int
    let awayScore: Int
    let homeLabel: String
    let awayLabel: String
    let shotClock: Int
    var shotClockReset: Int = 24
    let possessionHome: Bool
    var matchClock: String? = nil
    var targetText: String? = nil
    let homeColor: Color
    var awayColor: Color = FELDesign.Colors.danger

    private var digitCount: Int { layout == .threeVThree ? 2 : 2 }

    var body: some View {
        HStack(alignment: .center, spacing: FELDesign.Space.md) {
            teamColumn(label: homeLabel, score: homeScore, tint: homeColor, alignment: .leading)

            centerCluster

            teamColumn(label: awayLabel, score: awayScore, tint: awayColor, alignment: .trailing)
        }
        .padding(.horizontal, FELDesign.Space.lg)
        .padding(.vertical, FELDesign.Space.sm)
        .background {
            FELHudGlassBackground(accent: homeColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
        )
    }

    private func teamColumn(label: String, score: Int, tint: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            FELMicroLabel(text: label, color: tint.opacity(0.9))
            OdometerScore(
                value: score,
                digitCount: digitCount,
                color: FELDesign.Colors.textPrimary,
                accent: tint
            )
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var centerCluster: some View {
        VStack(spacing: 6) {
            if let matchClock {
                Text(matchClock)
                    .font(FELTypography.mono(13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                    .contentTransition(.numericText())
            }

            ShotClock(
                seconds: shotClock,
                resetValue: shotClockReset,
                accent: FELDesign.Colors.cyan,
                diameter: 44
            )

            PossessionIndicator(
                side: possessionHome ? .home : .away,
                homeColor: homeColor,
                awayColor: awayColor,
                homeLabel: homeLabel,
                awayLabel: awayLabel
            )

            if let targetText {
                Text(targetText.uppercased())
                    .font(FELTypography.mono(8, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    struct Demo: View {
        @State private var home = 18
        @State private var away = 14
        @State private var clock = 14
        @State private var possHome = true
        var body: some View {
            VStack(spacing: 32) {
                BasketballScoreboard(
                    layout: .headToHead,
                    homeScore: home,
                    awayScore: away,
                    homeLabel: "YOU",
                    awayLabel: "OPP",
                    shotClock: clock,
                    possessionHome: possHome,
                    matchClock: "07:42",
                    targetText: "First to 21",
                    homeColor: FELDesign.Colors.cyan
                )

                BasketballScoreboard(
                    layout: .threeVThree,
                    homeScore: 7,
                    awayScore: 9,
                    homeLabel: "SQUAD A",
                    awayLabel: "SQUAD B",
                    shotClock: 4,
                    possessionHome: false,
                    homeColor: FELDesign.Colors.success
                )

                HStack {
                    Button("+2") { home += 2 }.buttonStyle(FELGhostButtonStyle())
                    Button("Tick") { clock = max(0, clock - 1) }.buttonStyle(FELGhostButtonStyle())
                    Button("Poss") { possHome.toggle() }.buttonStyle(FELGhostButtonStyle())
                }
            }
            .padding(24)
            .background(FELDesign.Colors.ink)
        }
    }
    return Demo()
}
