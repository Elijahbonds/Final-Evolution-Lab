import SwiftUI

struct NeuralAuraBadge: View {
    let auraLevel: AuraLevel
    @State private var glowing = false

    private var auraColor: Color {
        switch auraLevel {
        case .baseline: .gray
        case .active: Theme.brandBlue
        case .primed: Theme.brandCyan
        case .maxIntent: Theme.elitePurple
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if auraLevel.glowIntensity > 0 {
                    Circle()
                        .fill(auraColor.opacity(glowing ? 0.4 : 0.15))
                        .frame(width: 20, height: 20)

                    Circle()
                        .fill(auraColor.opacity(glowing ? 0.6 : 0.3))
                        .frame(width: 12, height: 12)
                }

                Circle()
                    .fill(auraColor)
                    .frame(width: 6, height: 6)
            }

            Text(auraLevel.rawValue)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(auraColor)
                .tracking(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(auraColor.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(auraColor.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear {
            guard auraLevel.glowIntensity > 0 else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

struct ImpactFlashOverlay: View {
    let isActive: Bool
    let color: Color
    let intensity: Double

    var body: some View {
        if isActive {
            ZStack {
                color.opacity(intensity * 0.2)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [color.opacity(intensity * 0.3), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}

struct NeuralBurstIndicator: View {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        if isActive {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Theme.brandCyan.opacity(0.4), Theme.elitePurple.opacity(0.3), Theme.brandBlue.opacity(0.4), Theme.brandCyan.opacity(0.4)],
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: CGFloat(60 + ring * 20), height: CGFloat(60 + ring * 20))
                        .rotationEffect(.degrees(rotation + Double(ring) * 30))
                        .scaleEffect(scale)
                }

                VStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)

                    Text("BURST")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.1
                }
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

struct PRQTierBadge: View {
    let tier: PRQTier
    let prq: Double

    private var tierColor: Color {
        switch tier {
        case .diamond: Theme.brandCyan
        case .platinum: Color(white: 0.85)
        case .gold: .yellow
        case .silver: Color(white: 0.7)
        case .bronze: Color(red: 0.8, green: 0.5, blue: 0.2)
        case .unranked: .gray
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tier.displayIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tierColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(tier.rawValue)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(tierColor)
                    .tracking(1)

                Text(String(format: "%.1f PRQ", prq))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tierColor.opacity(0.08))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tierColor.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct GameActionFeedback: View {
    let text: String
    let isCritical: Bool
    let isNeuralBurst: Bool
    var isKarate: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if isCritical && !isKarate {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
            }

            if isNeuralBurst && !isKarate {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.elitePurple)
            }

            Text(text)
                .font(.system(size: isKarate ? 22 : 11, weight: .black, design: .monospaced))
                .foregroundStyle(isKarate ? .orange : .white.opacity(0.9))
                .shadow(color: isKarate ? .orange.opacity(0.7) : .clear, radius: 12)
        }
        .padding(.horizontal, isKarate ? 16 : 12)
        .padding(.vertical, isKarate ? 10 : 6)
        .background(
            isKarate ? AnyShapeStyle(.orange.opacity(0.12)) :
            (isCritical ? AnyShapeStyle(Theme.brandCyan.opacity(0.15)) :
            (isNeuralBurst ? AnyShapeStyle(Theme.elitePurple.opacity(0.15)) : AnyShapeStyle(.ultraThinMaterial)))
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isKarate ? Color.orange.opacity(0.4) :
                    (isCritical ? Theme.brandCyan.opacity(0.3) :
                    (isNeuralBurst ? Theme.elitePurple.opacity(0.3) : Color.white.opacity(0.1))),
                    lineWidth: isKarate ? 1.5 : 0.5
                )
        )
    }
}
