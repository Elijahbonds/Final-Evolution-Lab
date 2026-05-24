import SwiftUI

struct FELOverlayView: View {
    @State private var scoreManager = FELScoreManager.shared
    @State private var isAnimating: Bool = false
    @State private var showPulse: Bool = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                prqBadge
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var prqBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tierGradient)
                .symbolEffect(.pulse, options: .repeating, isActive: showPulse)

            VStack(alignment: .leading, spacing: 1) {
                Text("PRQ")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text("\(scoreManager.currentPrqScore)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(tierGradient)
                .frame(width: 2, height: 24)

            Text(scoreManager.prqTier)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(tierGradient)
                .tracking(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(tierGradient.opacity(0.3), lineWidth: 1)
                }
        }
        .onChange(of: scoreManager.currentPrqScore) { _, _ in
            withAnimation(.spring(duration: 0.4)) {
                isAnimating = true
            }
            showPulse = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                showPulse = false
                isAnimating = false
            }
        }
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .animation(.spring(duration: 0.3), value: isAnimating)
    }

    private var tierGradient: LinearGradient {
        switch scoreManager.tierColor {
        case "gold":
            LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "purple":
            LinearGradient(colors: [Theme.elitePurple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "blue":
            LinearGradient(colors: [Theme.brandBlue, Theme.flightBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "green":
            LinearGradient(colors: [Color.green, Color.mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            LinearGradient(colors: [Color.gray, Color.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
