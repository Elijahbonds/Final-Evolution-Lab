import SwiftUI

struct CreatorMarketplaceHubView: View {
    let viewModel: LabViewModel

    @State private var packCount: Int = 1
    @State private var lastPackPulls: [CreatorCardAsset] = []
    @State private var bidValues: [String: Int] = [:]
    @State private var feedbackBanner: MarketplaceFeedbackBanner?
    @State private var feedbackDismissTask: Task<Void, Never>?
    @State private var pendingConfirmation: MarketplaceConfirmation?

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
        .onDisappear {
            feedbackDismissTask?.cancel()
            feedbackDismissTask = nil
        }
        .overlay(alignment: .bottom) {
            if let feedbackBanner {
                HStack(spacing: 10) {
                    Image(systemName: feedbackBanner.isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feedbackBanner.message)
                            .font(.system(size: 12, weight: .bold))
                        if let detail = feedbackBanner.detail {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.black.opacity(0.75))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(feedbackBanner.isError ? Color.orange : Theme.brandBlue)
                .clipShape(.rect(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(item: $pendingConfirmation) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .default(Text(action.confirmButton)) {
                    performConfirmedAction(action)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Marketplace")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            Text("Auction House")
                .font(.system(size: 44, weight: .black))
                .italic()
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private var balanceStrip: some View {
        HStack(spacing: 10) {
            marketPill(icon: "diamond.fill", label: "Shards", value: "\(viewModel.profile.evolutionShards)", color: Theme.brandCyan)
            marketPill(icon: "creditcard.fill", label: "Pool credits", value: "\(viewModel.creatorMarketplace.servicePoolAvailableCredits)", color: Theme.brandBlue)
            marketPill(icon: "flame.fill", label: "Burned", value: "\(totalBurnedShards)", color: .orange)
        }
    }

    private var packSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Pack opening")

            HStack {
                Text("Packs: \(packCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Stepper("", value: $packCount, in: 1...10)
                    .labelsHidden()
                    .accessibilityLabel("Pack count")
                    .accessibilityValue("\(packCount)")
            }

            Button {
                pendingConfirmation = .openPacks(count: packCount)
            } label: {
                Text("Open \(packCount) pack • \(packCount * LabViewModel.creatorPackCostShards) shards")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
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
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(asset.rarity.rawValue.capitalized)
                                        .font(.system(size: 10, weight: .semibold))
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
            sectionLabel("Inventory")
            if viewModel.ownedCreatorAssets.isEmpty {
                emptyCard("No creator assets")
            } else {
                ForEach(viewModel.ownedCreatorAssets.prefix(24)) { asset in
                    if let card = cardTemplate(for: asset.templateCardId) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("\(asset.rarity.rawValue.capitalized) • \(asset.source.rawValue)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(rarityColor(asset.rarity))
                                }
                                Spacer()
                                if asset.isLockedInAuction {
                                    Text("Listed")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.orange.opacity(0.12))
                                        .clipShape(Capsule())
                                } else if asset.utilityActive(now: Date(), currentShardBalance: viewModel.profile.evolutionShards) {
                                    Text("Active")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }

                            HStack(spacing: 8) {
                                actionButton("Equip", color: Theme.brandBlue) {
                                    let ok = viewModel.equipOwnedCreatorCardAsset(assetId: asset.id)
                                    showFeedback(
                                        ok ? "Card equipped" : "Equip failed",
                                        detail: ok ? "Your active card boost has been updated." : "This card cannot be equipped right now.",
                                        isError: !ok
                                    )
                                }

                                actionButton("Maintain 24h", color: Theme.brandCyan) {
                                    pendingConfirmation = .maintenance(assetId: asset.id, hours: 24)
                                }

                                actionButton("Sign", color: .purple) {
                                    pendingConfirmation = .sign(assetId: asset.id)
                                }

                                actionButton("List", color: .orange) {
                                    let startingBid = suggestedStartBid(for: asset.rarity)
                                    let buyNow = startingBid * 2
                                    pendingConfirmation = .list(
                                        assetId: asset.id,
                                        startingBidShards: startingBid,
                                        buyNowShards: buyNow
                                    )
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
                sectionLabel("Active listings")
                Spacer()
                Button {
                    let expiringCount = viewModel.activeAuctionListings.filter { $0.expiresAt <= Date() }.count
                    pendingConfirmation = .settleExpired(count: expiringCount)
                } label: {
                    Text("Settle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
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
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(listing.sellerId == viewModel.profile.id ? "You" : listing.sellerId)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(listing.sellerId == viewModel.profile.id ? Theme.brandCyan : .secondary)
                        }

                        HStack {
                            Text("Current: \(listing.currentBidShards) sh")
                            Spacer()
                            if let buyNow = listing.buyNowShards {
                                Text("Buy Now: \(buyNow) sh")
                            }
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Button {
                                bidValues[listing.id, default: listing.currentBidShards + 100] += 100
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.brandBlue)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Increase bid")
                            Button {
                                bidValues[listing.id, default: listing.currentBidShards + 100] =
                                    max(listing.currentBidShards + 1, bidValues[listing.id, default: listing.currentBidShards + 100] - 100)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Decrease bid")

                            Text("Bid \(bidValues[listing.id, default: listing.currentBidShards + 100])")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            if listing.sellerId != viewModel.profile.id {
                                Button {
                                    let bid = bidValues[listing.id, default: listing.currentBidShards + 100]
                                    pendingConfirmation = .bid(listingId: listing.id, amountShards: bid)
                                } label: {
                                    Text("Bid")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .frame(minHeight: 44)
                                        .background(Theme.brandBlue)
                                        .clipShape(Capsule())
                                }
                                if listing.buyNowShards != nil {
                                    Button {
                                        pendingConfirmation = .buyNow(listingId: listing.id)
                                    } label: {
                                        Text("Buy now")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 8)
                                            .frame(minHeight: 44)
                                            .background(.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                            } else {
                                Text("Seller")
                                    .font(.system(size: 10))
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
                sectionLabel("Recent sales")
                Spacer()
                Button {
                    let claimed = viewModel.claimMySignatureRoyaltyCredits()
                    showFeedback(
                        claimed > 0 ? "Claimed \(claimed) royalty credits" : "No royalty credits",
                        detail: claimed > 0 ? "Royalty credits moved to your wallet." : "No claimable signature royalties available.",
                        isError: claimed == 0
                    )
                } label: {
                    Text("Claim royalty \(viewModel.myClaimableRoyaltyCredits)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
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
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Tax Burn: \(sale.burnedTaxShards) • Royalty: \(sale.royaltyCreditsPaid)cr")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(sale.salePriceShards) sh")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
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
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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

    private func showFeedback(_ message: String, detail: String? = nil, isError: Bool = false) {
        feedbackDismissTask?.cancel()
        withAnimation(.spring(response: 0.25)) {
            feedbackBanner = MarketplaceFeedbackBanner(message: message, detail: detail, isError: isError)
        }
        feedbackDismissTask = Task {
            try? await Task.sleep(for: .seconds(2.25))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    feedbackBanner = nil
                }
                feedbackDismissTask = nil
            }
        }
    }

    private func performConfirmedAction(_ action: MarketplaceConfirmation) {
        switch action {
        case let .openPacks(count):
            let pulls = viewModel.openCreatorPacks(count: count)
            lastPackPulls = pulls
            showFeedback(
                pulls.isEmpty ? "Pack open failed" : "Opened \(pulls.count) pack(s)",
                detail: pulls.isEmpty ? "Insufficient shards for this pack purchase." : "New assets were added to your inventory.",
                isError: pulls.isEmpty
            )
        case let .maintenance(assetId, hours):
            let ok = viewModel.activateCardMaintenance(assetId: assetId, hours: hours)
            showFeedback(
                ok ? "Maintenance extended" : "Maintenance failed",
                detail: ok ? "Card utility remains active." : "Not enough shards for maintenance cost.",
                isError: !ok
            )
        case let .sign(assetId):
            let ok = viewModel.signCardAsSignature(assetId: assetId)
            showFeedback(
                ok ? "Card signed" : "Signature cap reached",
                detail: ok ? "This asset can now accrue resale royalties." : "Creator signature mint cap has been reached.",
                isError: !ok
            )
        case let .list(assetId, startingBidShards, buyNowShards):
            let ok = viewModel.listOwnedCardForAuction(
                assetId: assetId,
                startingBidShards: startingBidShards,
                buyNowShards: buyNowShards
            )
            showFeedback(
                ok ? "Listed for auction" : "Listing failed",
                detail: ok ? "Card was locked and posted to active listings." : "Card is not eligible for listing.",
                isError: !ok
            )
        case let .bid(listingId, amountShards):
            let ok = viewModel.placeBidOnListing(listingId: listingId, bidAmountShards: amountShards)
            showFeedback(
                ok ? "Bid placed" : "Bid rejected",
                detail: ok ? "Your shards are escrowed until outbid/settled." : "Bid must exceed current price and available shards.",
                isError: !ok
            )
        case let .buyNow(listingId):
            let ok = viewModel.buyNowListing(listingId: listingId)
            showFeedback(
                ok ? "Bought listing" : "Buy now failed",
                detail: ok ? "Asset transferred to your inventory." : "Insufficient shards or listing no longer available.",
                isError: !ok
            )
        case .settleExpired:
            viewModel.settleExpiredAuctionListings()
            showFeedback("Expired listings settled", detail: "Eligible auctions were processed.")
        }
    }
}

private struct MarketplaceFeedbackBanner {
    let message: String
    let detail: String?
    let isError: Bool
}

private enum MarketplaceConfirmation: Identifiable {
    case openPacks(count: Int)
    case maintenance(assetId: String, hours: Int)
    case sign(assetId: String)
    case list(assetId: String, startingBidShards: Int, buyNowShards: Int?)
    case bid(listingId: String, amountShards: Int)
    case buyNow(listingId: String)
    case settleExpired(count: Int)

    var id: String {
        switch self {
        case let .openPacks(count): return "openpacks-\(count)"
        case let .maintenance(assetId, hours): return "maint-\(assetId)-\(hours)"
        case let .sign(assetId): return "sign-\(assetId)"
        case let .list(assetId, startingBidShards, buyNowShards):
            return "list-\(assetId)-\(startingBidShards)-\(buyNowShards ?? 0)"
        case let .bid(listingId, amountShards): return "bid-\(listingId)-\(amountShards)"
        case let .buyNow(listingId): return "buynow-\(listingId)"
        case let .settleExpired(count): return "settle-\(count)"
        }
    }

    var title: String {
        switch self {
        case let .openPacks(count): return "Open \(count) pack(s)?"
        case .maintenance: return "Extend maintenance?"
        case .sign: return "Sign this card?"
        case .list: return "List this card for auction?"
        case let .bid(_, amountShards): return "Place bid of \(amountShards) shards?"
        case .buyNow: return "Buy listing now?"
        case let .settleExpired(count):
            return count > 0 ? "Settle \(count) expired listing(s)?" : "Run settlement scan?"
        }
    }

    var message: String {
        switch self {
        case .openPacks:
            return "This spends shards and cannot be reversed."
        case .maintenance:
            return "Maintenance spends shards to keep card utility active."
        case .sign:
            return "Signing is limited and affects rarity/royalty state."
        case .list:
            return "Listing locks this card until sold, expired, or canceled."
        case .bid:
            return "Bid amount is escrowed until settlement or outbid."
        case .buyNow:
            return "This immediately purchases and settles the listing."
        case .settleExpired:
            return "Settlement processes expired auctions and releases outcomes."
        }
    }

    var confirmButton: String {
        switch self {
        case .openPacks: return "Open Packs"
        case .maintenance: return "Extend"
        case .sign: return "Sign"
        case .list: return "List"
        case .bid: return "Place Bid"
        case .buyNow: return "Buy Now"
        case .settleExpired: return "Settle"
        }
    }
}
