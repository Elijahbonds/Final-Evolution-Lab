import SwiftUI

struct CreatorCardBoostView: View {
    let viewModel: LabViewModel
    @State private var selectedCard: CreatorCard?
    @State private var showConfirm = false
    @State private var showInsufficientShards = false
    @State private var showMarketplace = false
    @State private var appeared = false

    private var activeCard: CreatorCardState? {
        viewModel.profile.activeCreatorCard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CREATOR CARDS")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15))
                        .tracking(2)

                    Text("Boost Your Avatar")
                        .font(.system(.title3, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showMarketplace = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cart.fill")
                            Text("MARKET")
                        }
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.brandCyan.opacity(0.15))
                        .foregroundStyle(Theme.brandCyan)
                        .clipShape(Capsule())
                    }

                    if activeCard != nil {
                        Button {
                            viewModel.clearCreatorCard()
                        } label: {
                            Text("REMOVE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if let active = activeCard,
               let card = CreatorCard.catalog.first(where: { $0.id == active.cardId }) {
                ActiveCardBanner(
                    card: card,
                    state: active,
                    athleteProfileId: viewModel.profile.id
                )
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(CreatorCard.catalog) { card in
                        let isOwned = viewModel.profile.ownsCard(card.id)
                        CreatorCardCell(
                            card: card,
                            isActive: activeCard?.cardId == card.id,
                            isOwned: isOwned,
                            canAfford: isOwned || viewModel.profile.evolutionShards >= card.costShards
                        ) {
                            if activeCard?.cardId == card.id { return }
                            if isOwned {
                                viewModel.applyCreatorCard(card)
                                return
                            }
                            if viewModel.profile.evolutionShards < card.costShards {
                                showInsufficientShards = true
                                return
                            }
                            selectedCard = card
                            showConfirm = true
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.95, green: 0.49, blue: 0.15).opacity(0.15), lineWidth: 1)
                )
        )
        .alert("Activate Creator Card", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) { selectedCard = nil }
            Button("Activate") {
                if let card = selectedCard {
                    viewModel.applyCreatorCard(card)
                }
                selectedCard = nil
            }
        } message: {
            if let card = selectedCard {
                Text("Spend \(card.costShards) shards to activate \(card.title)? This will boost your avatar's abilities with \(card.creatorName)'s data.")
            }
        }
        .alert("Insufficient Shards", isPresented: $showInsufficientShards) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Earn more shards through workouts and arena matches to unlock creator cards.")
        }
        .sheet(isPresented: $showMarketplace) {
            CardMarketplaceView(viewModel: viewModel)
        }
    }
}

struct ActiveCardBanner: View {
    let card: CreatorCard
    let state: CreatorCardState
    /// Included in QR payload when sharing the equipped card link.
    var athleteProfileId: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(card.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: card.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(card.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                        .tracking(1)

                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                        .symbolEffect(.pulse)
                }

                Text(card.title)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(Int(card.metricsBoost.prqScore)) PRQ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(card.accentColor)

                    Text("+\(Int(card.metricsBoost.verticalPotential)) VERT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    CreatorCardQRThumbnail(
                        payload: card.qrPayload(includeAthleteId: athleteProfileId),
                        dimension: 56
                    )
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("SCAN")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(card.accentColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(card.accentColor.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct CreatorCardCell: View {
    let card: CreatorCard
    let isActive: Bool
    var isOwned: Bool = false
    let canAfford: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(card.accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: isActive ? "checkmark" : card.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isActive ? .green : card.accentColor)
                    }

                    Spacer()

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(card.creatorName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(card.accentColor.opacity(0.7))
                    .tracking(1)

                Text(card.title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                CreatorCardQRThumbnail(
                    payload: card.qrPayload(includeAthleteId: nil),
                    dimension: 48
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                HStack(spacing: 4) {
                    Image(systemName: isOwned ? "checkmark.seal.fill" : "diamond.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(isOwned ? .green : Theme.brandCyan)

                    Text(isActive ? "EQUIPPED" : (isOwned ? "OWNED" : "\(card.costShards)"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(isActive ? .green : (isOwned ? .green.opacity(0.8) : (canAfford ? .white : .red)))
                }
            }
            .padding(14)
            .frame(width: 170, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? card.accentColor.opacity(0.04) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? card.accentColor.opacity(0.2) : Theme.cardBorder, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isActive)
        .opacity(isActive ? 0.85 : 1.0)
    }
}
