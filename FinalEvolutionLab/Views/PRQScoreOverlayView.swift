import SwiftUI

struct PRQScoreOverlayView: View {
    @State private var scoreManager = PRQScoreManager.shared
    @State private var showDetail: Bool = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                compactBadge
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }

            if showDetail {
                Spacer()
                detailCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer()
            }
        }
    }

    private var compactBadge: some View {
        Button {
            withAnimation(.spring(duration: 0.35)) {
                showDetail.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 8, height: 8)

                Text("\(scoreManager.currentPrqScore)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(badgeColor.opacity(0.4), lineWidth: 1)
                    }
            }
        }
    }

    private var detailCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PERFORMANCE READINESS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)

                    Text("\(scoreManager.currentPrqScore)")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(scoreManager.prqTier)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background {
                            Capsule().fill(badgeColor.opacity(0.15))
                        }

                    Text("NEURAL DRIVE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(badgeColor)
                        .frame(width: geo.size.width * CGFloat(scoreManager.currentPrqScore) / 100.0)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private var badgeColor: Color {
        switch scoreManager.tierColor {
        case "gold": .yellow
        case "purple": Theme.elitePurple
        case "blue": Theme.brandBlue
        case "green": .green
        default: .gray
        }
    }
}
