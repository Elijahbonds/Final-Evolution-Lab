import SwiftUI

struct CreatorMarketplaceHubView: View {
    let viewModel: LabViewModel

    @State private var packCount: Int = 1
    @State private var lastPackPulls: [CreatorCardAsset] = []
    @State private var bidValues: [String: Int] = [:]
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                balanceStrip
                packSection
                inventorySection
                activeListingsSection
                salesHistorySection
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .onAppear {
            viewModel.seedMarketplaceDemoLiquidityIfNeeded()
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.brandBlue)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MARKET LAYER")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.orange)
                .tracking(4)

            Text("Auction House")
                .font(.system(size: 44, weight: .black))
                .italic()
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private var balanceStrip: some View {
        HStack(spacing: 10) {
            marketPill(icon: "diamond.fill", label: "SHARDS", value: "\(viewModel.profile.evolutionShards)", color: Theme.brandCyan)
            marketPill(icon: "creditcard.fill", label: "POOL CREDITS", value: "\(viewModel.creatorMarketplace.servicePoolAvailableCredits)", color: Theme.brandBlue)
            marketPill(icon: "flame.fill", label: "BURNED", value: "\(totalBurnedShards)", color: .orange)
        }
    }

    private var packSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("PACK OPENING")

            HStack {
                Text("Packs: \(packCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Stepper("", value: $packCount, in: 1...10)
                    .labelsHidden()
            }

            Button {
                let pulls = viewModel.openCreatorPacks(count: packCount)
                lastPackPulls = pulls
                showToast(pulls.isEmpty ? "Pack open failed" : "Opened \(pulls.count) pack(s)")
            } label: {
                Text("OPEN \(packCount) PACK • \(packCount * LabViewModel.creatorPackCostShards) SHARDS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.orange)
                    .clipShape(.rect(cornerRadius: 10))
            }

            if !lastPackPulls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lastPackPulls) { asset in
                            if let card = cardTemplate(for: asset.templateCardId) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.title)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(asset.rarity.rawValue.uppercased())
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundStyle(rarityColor(asset.rarity))
                                }
                                .padding(8)
                                .frame(width: 160, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.04))
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("INVENTORY")
            if viewModel.ownedCreatorAssets.isEmpty {
                emptyCard("No creator assets")
            } else {
                ForEach(viewModel.ownedCreatorAssets.prefix(24)) { asset in
                    if let card = cardTemplate(for: asset.templateCardId) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.title.uppercased())
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                    Text("\(asset.rarity.rawValue.uppercased()) • \(asset.source.rawValue)")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(rarityColor(asset.rarity))
                                }
                                Spacer()
                                if asset.isLockedInAuction {
                                    Text("LISTED")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.12))
                                        .clipShape(Capsule())
                                } else if asset.utilityActive(now: Date(), currentShardBalance: viewModel.profile.evolutionShards) {
                                    Text("ACTIVE")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }

                            HStack(spacing: 8) {
                                actionButton("EQUIP", color: Theme.brandBlue) {
                                    let ok = viewModel.equipOwnedCreatorCardAsset(assetId: asset.id)
                                    showToast(ok ? "Card equipped" : "Equip failed")
                                }

                                actionButton("MAINT 24H", color: Theme.brandCyan) {
                                    let ok = viewModel.activateCardMaintenance(assetId: asset.id, hours: 24)
                                    showToast(ok ? "Maintenance extended" : "Not enough shards")
                                }

                                actionButton("SIGN", color: .purple) {
                                    let ok = viewModel.signCardAsSignature(assetId: asset.id)
                                    showToast(ok ? "Card signed" : "Signature cap reached")
                                }

                                actionButton("LIST", color: .orange) {
                                    let startingBid = suggestedStartBid(for: asset.rarity)
                                    let buyNow = startingBid * 2
                                    let ok = viewModel.listOwnedCardForAuction(
                                        assetId: asset.id,
                                        startingBidShards: startingBid,
                                        buyNowShards: buyNow
                                    )
                                    showToast(ok ? "Listed for auction" : "Listing failed")
                                }
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.03))
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var activeListingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("ACTIVE LISTINGS")
                Spacer()
                Button {
                    viewModel.settleExpiredAuctionListings()
                    showToast("Expired listings settled")
                } label: {
                    Text("SETTLE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.foundationGreen)
                        .clipShape(Capsule())
                }
            }

            if viewModel.activeAuctionListings.isEmpty {
                emptyCard("No active listings")
            } else {
                ForEach(viewModel.activeAuctionListings) { listing in
                    let card = cardTemplate(for: listing.templateCardId)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(card?.title ?? listing.templateCardId)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(listing.sellerId == viewModel.profile.id ? "YOU" : listing.sellerId)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(listing.sellerId == viewModel.profile.id ? Theme.brandCyan : .secondary)
                        }

                        HStack {
                            Text("Current: \(listing.currentBidShards) sh")
                            Spacer()
                            if let buyNow = listing.buyNowShards {
                                Text("Buy Now: \(buyNow) sh")
                            }
                        }
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Button {
                                bidValues[listing.id, default: listing.currentBidShards + 100] += 100
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.brandBlue)
                            }
                            Button {
                                bidValues[listing.id, default: listing.currentBidShards + 100] =
                                    max(listing.currentBidShards + 1, bidValues[listing.id, default: listing.currentBidShards + 100] - 100)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }

                            Text("Bid \(bidValues[listing.id, default: listing.currentBidShards + 100])")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)

                            Spacer()

                            if listing.sellerId != viewModel.profile.id {
                                Button {
                                    let bid = bidValues[listing.id, default: listing.currentBidShards + 100]
                                    let ok = viewModel.placeBidOnListing(listingId: listing.id, bidAmountShards: bid)
                                    showToast(ok ? "Bid placed" : "Bid rejected")
                                } label: {
                                    Text("BID")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Theme.brandBlue)
                                        .clipShape(Capsule())
                                }
                                if listing.buyNowShards != nil {
                                    Button {
                                        let ok = viewModel.buyNowListing(listingId: listing.id)
                                        showToast(ok ? "Bought listing" : "Buy now failed")
                                    } label: {
                                        Text("BUY NOW")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                            } else {
                                Text("Seller")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var salesHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("RECENT SALES")
                Spacer()
                Button {
                    let claimed = viewModel.claimMySignatureRoyaltyCredits()
                    showToast(claimed > 0 ? "Claimed \(claimed) royalty credits" : "No royalty credits")
                } label: {
                    Text("CLAIM ROYALTY \(viewModel.myClaimableRoyaltyCredits)")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.brandBlue)
                        .clipShape(Capsule())
                }
            }
            let recent = viewModel.creatorMarketplace.salesHistory.suffix(5).reversed()
            if recent.isEmpty {
                emptyCard("No sales history")
            } else {
                ForEach(Array(recent), id: \.id) { sale in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cardTemplate(for: sale.templateCardId)?.title ?? sale.templateCardId)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("Tax Burn: \(sale.burnedTaxShards) • Royalty: \(sale.royaltyCreditsPaid)cr")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(sale.salePriceShards) sh")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var totalBurnedShards: Int {
        viewModel.creatorMarketplace.shardBurnedByPackPulls +
        viewModel.creatorMarketplace.shardBurnedByMaintenance +
        viewModel.creatorMarketplace.shardBurnedByAuctionTax +
        viewModel.creatorMarketplace.shardBurnedByServiceBridge
    }

    private func cardTemplate(for cardId: String) -> CreatorCard? {
        CreatorCard.catalog.first(where: { $0.id == cardId })
    }

    private func suggestedStartBid(for rarity: CreatorCardRarity) -> Int {
        switch rarity {
        case .common: return 800
        case .uncommon: return 1200
        case .rare: return 2200
        case .epic: return 3500
        case .legendary: return 6500
        case .signature: return 12000
        }
    }

    private func rarityColor(_ rarity: CreatorCardRarity) -> Color {
        switch rarity {
        case .common: .secondary
        case .uncommon: Theme.foundationGreen
        case .rare: Theme.brandBlue
        case .epic: Theme.elitePurple
        case .legendary: .orange
        case .signature: .yellow
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.tertiary)
            .tracking(2)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.03))
            )
    }

    private func actionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(color)
                .clipShape(Capsule())
        }
    }

    private func marketPill(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.cardBackground)
        )
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.25)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }
}
