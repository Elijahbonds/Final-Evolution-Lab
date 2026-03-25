import SwiftUI
import UIKit

/// High-fidelity “Creator Card” export for System Scan + Arena wins — broadcast-style dark layout, cyan Neuro-Mechanic accents.
/// Pass a **3D avatar snapshot** (e.g. RealityKit / SceneKit render, or cropped photo) when available.
enum UFELAthleteCardGenerator {

    struct CardInput: Sendable {
        var avatarSnapshot: UIImage?
        var prqScore: Double
        var verticalEstimateInches: Double
        var displayName: String
        var athleteTag: String
        var tierLabel: String
        var subtitle: String
        /// Gear + Creator Card boosts (e.g. MAG +3%, +5 PRQ).
        var attributeBoostLines: [String]
        /// Elite Sovereign Gear — drives holographic chrome on the card chrome.
        var tierVisual: CardTierVisual
        /// Non-nil when a Creator Card “Stand” is gold/diamond tier (social proof).
        var standTierBadge: String?
        /// High-tier Creator Card signature move label (e.g. "APEX IGNITION"); mirrors Unreal `EFELSignatureTrait`.
        var signatureMoveBadge: String?
    }

    enum CardTierVisual: Sendable {
        case standard
        case gold
        case diamond
    }

    @MainActor
    static func renderUIImage(
        input: CardInput,
        size: CGSize = CGSize(width: 390, height: 520),
        scale: CGFloat? = nil
    ) -> UIImage? {
        let resolvedScale = scale ?? UIScreen.main.scale
        let view = FELAthleteCardCanvas(input: input)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = resolvedScale
        return renderer.uiImage
    }

    @MainActor
    static func cardInput(from viewModel: LabViewModel) -> CardInput {
        let inches = viewModel.profile.systemScan?.verticalEstimateInches
            ?? Double(viewModel.profile.metrics.verticalPotential) * 0.28
        let gear = FELGearBoostCalculator.aggregatedMultipliers(profile: viewModel.profile)
        let tierVisual: CardTierVisual = {
            if gear.motionWarp >= 1.045 || gear.jumpVelocity >= 1.045 { return .diamond }
            if gear.motionWarp >= 1.03 || gear.jumpVelocity >= 1.03 { return .gold }
            return .standard
        }()
        let standTier = FELGearBoostCalculator.stoodCardTierString(for: viewModel.profile.activeCreatorCard)
        let standBadge: String? = standTier == "standard" ? nil : "\(standTier.uppercased()) STAND"
        let signatureBadge: String? = {
            guard let a = viewModel.profile.activeCreatorCard,
                  let c = CreatorCard.catalog.first(where: { $0.id == a.cardId }),
                  c.signatureTraitId != nil
            else { return nil }
            return c.signatureMoveDisplayName
        }()
        return CardInput(
            avatarSnapshot: FELAvatarSnapshotStore.shared.latestSnapshot,
            prqScore: viewModel.effectiveMetrics.prqScore,
            verticalEstimateInches: inches,
            displayName: viewModel.profile.displayName,
            athleteTag: viewModel.profile.athleteTag,
            tierLabel: viewModel.userPRQTier.rawValue,
            subtitle: "FINAL EVOLUTION LAB",
            attributeBoostLines: FELGearBoostCalculator.displayBoostLines(profile: viewModel.profile),
            tierVisual: tierVisual,
            standTierBadge: standBadge,
            signatureMoveBadge: signatureBadge
        )
    }

    @MainActor
    static func renderFromLabViewModel(_ viewModel: LabViewModel) -> UIImage? {
        renderUIImage(input: cardInput(from: viewModel))
    }
}

/// Optional hook: assign a UIImage after capturing from 3D preview / Unreal bridge.
@MainActor
final class FELAvatarSnapshotStore {
    static let shared = FELAvatarSnapshotStore()
    var latestSnapshot: UIImage?
    private init() {}
}

// MARK: - SwiftUI layout (broadcast card)

struct FELAthleteCardCanvas: View {
    let input: UFELAthleteCardGenerator.CardInput

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Theme.deepBlack,
                    Color(red: 0.04, green: 0.06, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Theme.brandCyan.opacity(0.12), Color.clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 280
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEURO-MECHANIC")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Theme.brandCyan.opacity(0.9))
                        Text(input.subtitle.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.18)))
                }
                .padding(.bottom, 18)

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    tierChromeGradient(input.tierVisual),
                                    lineWidth: input.tierVisual == .standard ? 1.2 : 1.8
                                )
                        )

                    if let img = input.avatarSnapshot {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(10)
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: [Theme.brandBlue.opacity(0.25), Theme.brandCyan.opacity(0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            Image(systemName: "figure.run")
                                .font(.system(size: 72, weight: .ultraLight))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(10)
                    }
                }
                .frame(maxWidth: .infinity)
                .shadow(color: Theme.brandBlue.opacity(0.2), radius: 20, y: 8)
                .overlay(alignment: .topLeading) {
                    if let badge = input.standTierBadge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(
                                        input.tierVisual == .diamond
                                            ? Color.white.opacity(0.22)
                                            : Color.yellow.opacity(0.22)
                                    )
                                    .overlay(Capsule().strokeBorder(Theme.brandCyan.opacity(0.5), lineWidth: 0.8))
                            )
                            .padding(18)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let sig = input.signatureMoveBadge {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("SIGNATURE MOVE")
                                .font(.system(size: 6, weight: .heavy, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(.white.opacity(0.75))
                            Text(sig.uppercased())
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.92, blue: 0.15),
                                            Theme.brandCyan,
                                            Color(red: 0.65, green: 0.25, blue: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Theme.brandCyan.opacity(0.9), radius: 8)
                                .shadow(color: Color(red: 1, green: 0.85, blue: 0.2).opacity(0.55), radius: 4)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.black.opacity(0.55))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Theme.brandCyan.opacity(0.85), Color.white.opacity(0.35)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.2
                                        )
                                )
                        )
                        .padding(18)
                    }
                }

                Spacer().frame(height: 16)

                Text(input.displayName.uppercased())
                    .font(.system(size: 22, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(input.athleteTag)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan.opacity(0.85))

                HStack(spacing: 10) {
                    Text(input.tierLabel)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().strokeBorder(Theme.brandCyan.opacity(0.35), lineWidth: 1))
                }
                .padding(.vertical, 10)

                if !input.attributeBoostLines.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(input.attributeBoostLines.enumerated()), id: \.offset) { _, line in
                            Text(line.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: input.tierVisual == .diamond
                                            ? [Color(red: 0.75, green: 0.95, blue: 1.0), Theme.brandCyan]
                                            : [Theme.foundationGreen, Theme.brandCyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                                )
                        }
                    }
                    .padding(.bottom, 8)
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRQ")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(Int(input.prqScore.rounded()))")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("VERTICAL EST.")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f\"", input.verticalEstimateInches))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.foundationGreen)
                    }
                }

                Spacer()

                HStack {
                    Spacer()
                    Text("SHARE YOUR EVOLUTION")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(3)
                }
            }
            .padding(22)
        }
    }

    private func tierChromeGradient(_ tier: UFELAthleteCardGenerator.CardTierVisual) -> LinearGradient {
        switch tier {
        case .standard:
            return LinearGradient(
                colors: [Theme.brandBlue.opacity(0.7), Theme.brandCyan.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [Color.yellow.opacity(0.95), Theme.brandCyan.opacity(0.55), Theme.brandBlue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .diamond:
            return LinearGradient(
                colors: [Color.white.opacity(0.98), Theme.brandCyan.opacity(0.85), Theme.brandBlue.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
