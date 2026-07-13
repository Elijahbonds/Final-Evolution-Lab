import SwiftUI

/// Mechanical rolling-digit score readout. Each digit is a vertically clipped
/// 0–9 column offset into place, so incrementing a score visibly "rolls" the
/// affected digits like an odometer.
struct OdometerScore: View {
    let value: Int
    var digitCount: Int? = nil
    var font: Font = FELDesign.Typography.statLarge
    var color: Color
    var accent: Color

    /// Fixed glyph cell size keeps the layout deterministic (no measurement race).
    var cellWidth: CGFloat = 20
    var cellHeight: CGFloat = 34

    private var digits: [Int] {
        let clamped = max(0, value)
        let raw = String(clamped).compactMap { $0.wholeNumberValue }
        let minCount = max(1, digitCount ?? 1)
        if raw.count >= minCount { return raw }
        return Array(repeating: 0, count: minCount - raw.count) + raw
    }

    var body: some View {
        HStack(spacing: 0) {
            // `enumerated` id keys by position so growing/shrinking digit counts
            // animate the newly-added leading cells too.
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                OdometerDigit(
                    digit: digit,
                    font: font,
                    color: color,
                    accent: accent,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                )
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: value)
    }
}

private struct OdometerDigit: View {
    let digit: Int
    let font: Font
    let color: Color
    let accent: Color
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0...9, id: \.self) { n in
                Text("\(n)")
                    .font(font)
                    .monospacedDigit()
                    .foregroundStyle(n == digit ? color : color.opacity(0.85))
                    .frame(width: cellWidth, height: cellHeight)
            }
        }
        // Slide the requested glyph into the single visible cell window.
        .offset(y: -CGFloat(digit) * cellHeight)
        .frame(width: cellWidth, height: cellHeight, alignment: .top)
        .clipped()
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: digit)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(accent.opacity(0.35))
                .frame(height: 1)
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var score = 7
        var body: some View {
            VStack(spacing: 24) {
                OdometerScore(value: score, digitCount: 3, color: FELDesign.Colors.textPrimary, accent: FELDesign.Colors.cyan)
                OdometerScore(value: score * 3, color: FELDesign.Colors.textPrimary, accent: FELDesign.Colors.purple)
                Button("Score +2") { score += 2 }
                    .buttonStyle(FELPrimaryButtonStyle())
            }
            .padding(40)
            .background(FELDesign.Colors.ink)
        }
    }
    return Demo()
}
