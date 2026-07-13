import SwiftUI

/// Countdown ring + centered numeral, styled after a broadcast shot clock.
/// The ring trims to `seconds / resetValue`; under `warnAt` it flips to the
/// danger color and pulses. The numeral count-transition uses numericText.
struct ShotClock: View {
    enum Style {
        case ring
        case numericOnly
    }

    let seconds: Int
    var resetValue: Int = 24
    var warnAt: Int = 5
    var accent: Color
    var diameter: CGFloat = 46
    var style: Style = .ring

    private var clamped: Int { max(0, seconds) }
    private var isWarning: Bool { clamped <= warnAt }
    private var tint: Color { isWarning ? FELDesign.Colors.danger : accent }

    private var progress: CGFloat {
        guard resetValue > 0 else { return 0 }
        return min(1, max(0, CGFloat(clamped) / CGFloat(resetValue)))
    }

    var body: some View {
        switch style {
        case .ring:
            ring
        case .numericOnly:
            numeral
                .frame(width: diameter, height: diameter)
        }
    }

    private var ring: some View {
        // TimelineView(.animation) drives the warn pulse and cancels cleanly
        // when the view leaves the hierarchy (no manual timers to invalidate).
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = isWarning ? (0.5 + 0.5 * sin(t * 6)) : 1
            ZStack {
                Circle()
                    .stroke(FELDesign.Colors.hairline, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)
                numeral
            }
            .frame(width: diameter, height: diameter)
            .opacity(isWarning ? (0.6 + 0.4 * pulse) : 1)
            .shadow(color: tint.opacity(isWarning ? 0.6 * pulse : 0), radius: 8)
        }
    }

    private var numeral: some View {
        Text("\(clamped)")
            .font(FELTypography.mono(diameter * 0.42, weight: .black))
            .monospacedDigit()
            .foregroundStyle(tint)
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy, value: clamped)
    }
}

#Preview {
    struct Demo: View {
        @State private var s = 24
        var body: some View {
            VStack(spacing: 24) {
                HStack(spacing: 24) {
                    ShotClock(seconds: s, accent: FELDesign.Colors.cyan)
                    ShotClock(seconds: 3, accent: FELDesign.Colors.cyan)
                    ShotClock(seconds: s, accent: FELDesign.Colors.purple, style: .numericOnly)
                }
                Button("Tick") { s = max(0, s - 1) }
                    .buttonStyle(FELPrimaryButtonStyle())
            }
            .padding(40)
            .background(FELDesign.Colors.ink)
        }
    }
    return Demo()
}
