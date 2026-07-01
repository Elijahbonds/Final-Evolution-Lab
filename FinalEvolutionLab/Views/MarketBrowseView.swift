import SwiftUI

// MARK: - MarketBrowseView
// Card market / Shard Shop for Creator Cards.
// NOT a game session — no session receipt, no PRQ delta, no shards per round.

struct MarketBrowseView: View {
    let viewModel: LabViewModel

    @State private var selectedFilter: CardRarity? = nil  // nil = All
    @State private var shakeCardId: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var appeared = false
    @State private var confirmPurchase: CreatorCard? = nil

    // MARK: - Rarity derivation (cost-based, no rarity field on model)
    enum CardRarity: String, CaseIterable {
        case common = "Common"
        case rare = "Rare"
        case elite = "Elite"

        static func from(costShards: Int) -> CardRarity {
            switch costShards {
            case ..<500: return .common
            case 500..<800: return .rare
            default: return .elite
            }
        }

        var color: Color {
            switch self {
            case .common: return .gray
            case .rare: return Theme.brandBlue
            case .elite: return Theme.elitePurple
            }
        }

        var glow: Color {
            switch self {
            case .common: return .gray.opacity(0.2)
            case .rare: return Theme.brandBlue.opacity(0.25)
            case .elite: return Theme.elitePurple.opacity(0.35)
            }
        }
    }

    // MARK: - Derived catalog

    private var featuredCard: CreatorCard? {
        CreatorCard.catalog.first { CardRarity.from(costShards: $0.costShards) == .elite }
    }

    private var filteredCards: [CreatorCard] {
        guard let filter = selectedFilter else { return CreatorCard.catalog }
        return CreatorCard.catalog.filter { CardRarity.from(costShards: $0.costShards) == filter }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                shardBalanceHeader
                if let featured = featuredCard {
                    featuredSpotlight(featured)
                }
                filterRow
                cardGrid
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack.ignoresSafeArea())
        .navigationTitle("Sovereign Shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Confirm Purchase", isPresented: Binding(
            get: { confirmPurchase != nil },
            set: { if !$0 { confirmPurchase = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmPurchase = nil }
            Button("Purchase") {
                if let card = confirmPurchase { completePurchase(card) }
            }
        } message: {
            if let card = confirmPurchase {
                Text("Spend \(card.costShards) shards to unlock \(card.title)?")
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5)) { appeared = true }
        }
    }

    // MARK: - Shard Balance Header

    private var shardBalanceHeader: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR SHARDS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                HStack(spacing: 8) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)

                    Text("\(viewModel.profile.evolutionShards)")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("CARDS OWNED")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Text("\(viewModel.profile.ownedCardIds.count) / \(CreatorCard.catalog.count)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.foundationGreen)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }

    // MARK: - Featured Spotlight

    private func featuredSpotlight(_ card: CreatorCard) -> some View {
        let rarity = CardRarity.from(costShards: card.costShards)
        let isOwned = viewModel.profile.ownedCardIds.contains(card.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                Text("FEATURED")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .tracking(3)
            }
            .padding(.bottom, 12)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [card.accentColor.opacity(0.3), card.accentColor.opacity(0.05)],
                                center: .center, startRadius: 4, endRadius: 36
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: card.iconName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(card.accentColor)
                        .shadow(color: card.accentColor.opacity(0.6), radius: 10)
                }

                VStack(alignment: .leading, spacing: 6) {
                    rarityBadge(rarity)

                    Text(card.title.uppercased())
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(card.showcaseTagline)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        prqBoostPill(card)
                        Spacer()
                        if isOwned {
                            equippedBadge
                        } else {
                            featuredBuyButton(card)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [rarity.color.opacity(0.1), .clear, rarity.color.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 20)
                    .stroke(rarity.color.opacity(0.4), lineWidth: 1)
            }
            .shadow(color: rarity.glow, radius: 12)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.5).delay(0.1), value: appeared)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "ALL", rarity: nil)
                ForEach(CardRarity.allCases, id: \.rawValue) { rarity in
                    filterChip(label: rarity.rawValue.uppercased(), rarity: rarity)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(label: String, rarity: CardRarity?) -> some View {
        let isSelected = selectedFilter == rarity
        let chipColor: Color = rarity?.color ?? Theme.brandBlue

        return Button {
            withAnimation(.snappy) { selectedFilter = rarity }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(isSelected ? chipColor : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? chipColor.opacity(0.15) : Color.white.opacity(0.04))
                        .overlay(
                            Capsule().stroke(isSelected ? chipColor.opacity(0.5) : .clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card Grid

    private var cardGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(Array(filteredCards.enumerated()), id: \.element.id) { index, card in
                creatorCardCell(card, index: index)
            }
        }
    }

    private func creatorCardCell(_ card: CreatorCard, index: Int) -> some View {
        let rarity = CardRarity.from(costShards: card.costShards)
        let isOwned = viewModel.profile.ownedCardIds.contains(card.id)
        let canAfford = viewModel.profile.evolutionShards >= card.costShards
        let isShaking = shakeCardId == card.id

        return VStack(alignment: .leading, spacing: 10) {
            // Icon + rarity row
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [card.accentColor.opacity(0.2), card.accentColor.opacity(0.04)],
                                center: .center, startRadius: 2, endRadius: 22
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: card.iconName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(card.accentColor)
                        .shadow(color: card.accentColor.opacity(0.5), radius: 6)
                }

                Spacer()
                rarityBadge(rarity)
            }

            // Name
            Text(card.creatorName.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(card.title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(card.accentColor.opacity(0.8))
                .lineLimit(1)

            // PRQ boost
            prqBoostPill(card)

            Spacer(minLength: 0)

            // Price / status
            if isOwned {
                equippedBadge
            } else {
                Button {
                    handleBuyTap(card: card, canAfford: canAfford)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(canAfford ? Theme.brandCyan : .red)

                        Text("\(card.costShards)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(canAfford ? .white : .red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canAfford ? Theme.brandBlue.opacity(0.18) : Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(canAfford ? Theme.brandBlue.opacity(0.4) : Color.red.opacity(0.3), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .offset(x: isShaking ? shakeOffset : 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.cardBackground)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [rarity.color.opacity(0.07), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isOwned ? Color.green.opacity(0.25) : rarity.color.opacity(0.18),
                        lineWidth: 0.75
                    )
            }
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.45).delay(Double(index) * 0.05), value: appeared)
    }

    // MARK: - Reusable Sub-views

    private func rarityBadge(_ rarity: CardRarity) -> some View {
        Text(rarity.rawValue.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundStyle(rarity.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(rarity.color.opacity(0.12))
                    .overlay(Capsule().stroke(rarity.color.opacity(0.3), lineWidth: 0.5))
            )
    }

    private func prqBoostPill(_ card: CreatorCard) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 8))
                .foregroundStyle(Theme.foundationGreen)
            Text("+\(card.metricsBoost.prqScore) PRQ")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.foundationGreen)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Theme.foundationGreen.opacity(0.1))
                .overlay(Capsule().stroke(Theme.foundationGreen.opacity(0.25), lineWidth: 0.5))
        )
    }

    private var equippedBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 9))
                .foregroundStyle(.green)
            Text("EQUIPPED")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    private func featuredBuyButton(_ card: CreatorCard) -> some View {
        let canAfford = viewModel.profile.evolutionShards >= card.costShards
        return Button {
            handleBuyTap(card: card, canAfford: canAfford)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(canAfford ? Theme.brandCyan : .red)
                Text("\(card.costShards)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(canAfford ? .white : .red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(canAfford ? Theme.brandBlue.opacity(0.2) : Color.red.opacity(0.1))
                    .overlay(Capsule().stroke(canAfford ? Theme.brandBlue.opacity(0.5) : Color.red.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .offset(x: shakeCardId == card.id ? shakeOffset : 0)
    }

    // MARK: - Purchase Logic

    private func handleBuyTap(card: CreatorCard, canAfford: Bool) {
        if !canAfford {
            triggerShake(cardId: card.id)
            return
        }
        confirmPurchase = card
    }

    private func completePurchase(_ card: CreatorCard) {
        viewModel.profile.evolutionShards -= card.costShards
        viewModel.profile.ownedCardIds.append(card.id)
        SaveSystem.saveProfile(viewModel.profile)
        confirmPurchase = nil
    }

    private func triggerShake(cardId: String) {
        shakeCardId = cardId
        withAnimation(.easeInOut(duration: 0.06).repeatCount(5, autoreverses: true)) {
            shakeOffset = 6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            shakeOffset = 0
            shakeCardId = nil
        }
    }
}
