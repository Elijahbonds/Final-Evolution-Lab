import SwiftUI
import FirebaseDataConnect
import SocialDataConnect

struct CardMarketplaceView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: LabViewModel
    
    @State private var activeListings: [ListActiveCardMarketListingsQuery.Data.CardMarketListing] = []
    @State private var mySqlUserId: UUID? = nil
    
    @State private var selectedTab: MarketplaceTab = .buy
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    // Listing creation flow state
    @State private var listingCard: CreatorCard? = nil
    @State private var listingPriceString: String = ""
    @State private var isListingInProgress = false
    
    // Purchase flow state
    @State private var buyingCard: ListActiveCardMarketListingsQuery.Data.CardMarketListing? = nil
    @State private var isBuyingInProgress = false
    
    enum MarketplaceTab {
        case buy
        case sell
        case myListings
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        FELLumaShopViewport(
                            height: 168,
                            caption: FELEconomyLabels.marketplaceTitle,
                            subtitle: "Trade creator cards with other athletes",
                            accent: Theme.brandCyan,
                            neuralDrive: viewModel.effectiveMetrics.neuralDrive
                        )
                        .padding(.top, 4)

                        balanceHeader
                        tabSelector
                        
                        if isLoading {
                            loadingSpinner
                        } else if let error = errorMessage {
                            errorOverlay(error)
                        } else {
                            switch selectedTab {
                            case .buy:
                                buyTabContent
                            case .sell:
                                sellTabContent
                            case .myListings:
                                myListingsTabContent
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                
                // Listing modal overlay
                if let card = listingCard {
                    listingDialog(for: card)
                }
                
                // Purchase confirmation modal overlay
                if let listing = buyingCard {
                    purchaseConfirmationDialog(for: listing)
                }
            }
            .navigationTitle(FELEconomyLabels.marketplaceTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                        .font(.system(.body, design: .monospaced))
                }
                ToolbarItem(placement: .principal) {
                    FELPreviewLabel(text: FELPremiumCopy.Preview.cardMarket)
                }
            }
            .onAppear {
                initializeMarketplace()
            }
        }
    }
    
    private var balanceHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FELEconomyLabels.shardBalance.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.brandCyan)
                        Text("\(viewModel.profile.evolutionShards)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(FELEconomyLabels.shards.lowercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                
                Text(FELEconomyLabels.marketplaceConnected.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.brandCyan.opacity(0.12))
                    .foregroundStyle(Theme.brandCyan)
                    .clipShape(Capsule())
            }
            
            if viewModel.profile.pendingRoyaltyShards > 0 {
                Divider()
                    .background(Theme.cardBorder)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PENDING ROYALTIES")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                        Text("\(viewModel.profile.pendingRoyaltyShards) Shards")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    
                    Button {
                        claimRoyaltiesFlow()
                    } label: {
                        Text("Claim Royalties")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.brandCyan)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
    
    private var tabSelector: some View {
        HStack(spacing: 4) {
            tabButton(title: "Buy Cards", target: .buy)
            tabButton(title: "List for Sale", target: .sell)
            tabButton(title: "My Listings", target: .myListings)
        }
        .padding(4)
        .background(Theme.slateCard)
        .cornerRadius(10)
    }
    
    private func tabButton(title: String, target: MarketplaceTab) -> some View {
        Button {
            withAnimation(.snappy) { selectedTab = target }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selectedTab == target ? Theme.brandCyan : Color.clear)
                .foregroundStyle(selectedTab == target ? .black : .white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
    
    private var loadingSpinner: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.brandCyan)
            Text(FELEconomyLabels.loadingMarketplace)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.brandCyan)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func errorOverlay(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.red)
            Text(FELEconomyLabels.connectionError)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.red)
            Text(msg)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                initializeMarketplace()
            }
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Buy Tab Content
    
    private var buyTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Available Now")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            
            let listings = activeListings.filter { listing in
                guard let myId = mySqlUserId else { return true }
                return listing.seller.id != myId
            }
            
            if listings.isEmpty {
                marketplaceEmptyState(
                    icon: "square.grid.2x2.fill",
                    title: "No cards for sale yet",
                    subtitle: "Check back later or list one of your owned cards."
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(listings) { listing in
                        marketListingCard(listing, isOwnListing: false, compact: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Sell Tab Content
    
    private var sellTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Cards")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            
            let ownedCards = CreatorCard.catalog.filter { viewModel.profile.ownsCard($0.id) }
            
            if ownedCards.isEmpty {
                marketplaceEmptyState(
                    icon: "lock.fill",
                    title: "No creator cards yet",
                    subtitle: "Purchase cards in the shop or marketplace to list them here."
                )
            } else {
                ForEach(ownedCards) { card in
                    ownedCardMarketRow(card)
                }
            }
        }
    }
    
    // MARK: - My Listings Tab Content
    
    private var myListingsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Listings")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            
            let myListings = activeListings.filter { listing in
                guard let myId = mySqlUserId else { return false }
                return listing.seller.id == myId
            }
            
            if myListings.isEmpty {
                marketplaceEmptyState(
                    icon: "list.bullet.clipboard",
                    title: "No active listings",
                    subtitle: "List a card from the Sell tab to get started."
                )
            } else {
                ForEach(myListings) { listing in
                    marketListingCard(listing, isOwnListing: true, compact: false)
                }
            }
        }
    }
    
    private func marketplaceEmptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Subviews
    
    private func marketListingCard(
        _ listing: ListActiveCardMarketListingsQuery.Data.CardMarketListing,
        isOwnListing: Bool,
        compact: Bool = false
    ) -> some View {
        let matchingCard = CreatorCard.catalog.first(where: { $0.id == listing.catalogCardId })
        let accentColor = matchingCard?.accentColor ?? Theme.brandCyan
        
        return VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: matchingCard?.iconName ?? "crown")
                            .foregroundStyle(accentColor)
                        Text(matchingCard?.creatorName ?? "Creator")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accentColor)
                    }
                    
                    Text(matchingCard?.title ?? "Creator Card")
                        .font(.system(size: compact ? 14 : 16, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(compact ? 2 : 3)
                    
                    if !compact {
                        Text(matchingCard?.description ?? "Unique style multipliers and physics modifiers.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            
            if !compact {
                Divider()
                    .background(Theme.cardBorder)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Seller")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(listing.seller.username)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(FELEconomyLabels.shardCost(listing.priceShards))
                        .font(.system(size: compact ? 12 : 13, weight: .black))
                        .foregroundStyle(Theme.brandCyan)
                    
                    if isOwnListing {
                        Button {
                            deactivateListing(listing)
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            buyingCard = listing
                        } label: {
                            Text("Buy")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(Theme.brandCyan)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accentColor.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
    
    private func ownedCardMarketRow(_ card: CreatorCard) -> some View {
        HStack {
            Image(systemName: card.iconName)
                .font(.system(size: 18))
                .foregroundStyle(card.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(card.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            
            Button {
                listingCard = card
                listingPriceString = ""
            } label: {
                Text("List for Sale")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.brandCyan.opacity(0.1))
                    .foregroundStyle(Theme.brandCyan)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.brandCyan.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(Theme.slateCard)
        .cornerRadius(12)
    }
    
    // MARK: - Overlay Dialogs
    
    private func listingDialog(for card: CreatorCard) -> some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 18) {
                Text("List Card for Sale")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Card")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(card.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Price (\(FELEconomyLabels.shards.lowercased()))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Enter amount", text: $listingPriceString)
                        .keyboardType(.numberPad)
                        .font(.system(size: 15, design: .monospaced))
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 12) {
                    Button("CANCEL") {
                        listingCard = nil
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button {
                        submitListingOffer(card: card)
                    } label: {
                        HStack {
                            if isListingInProgress {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text("Confirm Listing")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Theme.brandCyan)
                        .cornerRadius(6)
                    }
                    .disabled(isListingInProgress)
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.brandCyan.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }
    
    private func purchaseConfirmationDialog(for listing: ListActiveCardMarketListingsQuery.Data.CardMarketListing) -> some View {
        let matchingCard = CreatorCard.catalog.first(where: { $0.id == listing.catalogCardId })
        
        return ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 18) {
                Text("Buy Creator Card")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Card")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(matchingCard?.title ?? "Creator Card")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Seller")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(listing.seller.username)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(FELEconomyLabels.shardCost(listing.priceShards))
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.brandCyan)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        buyingCard = nil
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    Button {
                        executePurchase(listing: listing)
                    } label: {
                        HStack {
                            if isBuyingInProgress {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text("Confirm Purchase")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Theme.brandCyan)
                        .cornerRadius(6)
                    }
                    .disabled(isBuyingInProgress)
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.brandCyan.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Logic & Actions
    
    private func initializeMarketplace() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Ensure Firebase is configured and user is signed into SQL
                TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
                
                // Get or create cached SQL user identity
                let name = viewModel.profile.displayName
                self.mySqlUserId = try await TrainingLabSocialBridge.shared.ensureSqlUserRegistration(displayName: name)
                
                // Load active listings
                try await refreshListings()
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func refreshListings() async throws {
        let result = try await DataConnect.socialConnector.listActiveCardMarketListingsQuery.execute()
        await MainActor.run {
            self.activeListings = result.data?.cardMarketListings ?? []
        }
    }
    
    private func submitListingOffer(card: CreatorCard) {
        guard let price = Int(listingPriceString), price > 0 else {
            FelToastCenter.shared.show("Enter a valid shard price greater than 0.", isError: true)
            return
        }
        
        isListingInProgress = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await DataConnect.socialConnector.createCardMarketListingMutation.execute(
                    catalogCardId: card.id,
                    priceShards: price
                )
                try await refreshListings()
                
                await MainActor.run {
                    isListingInProgress = false
                    listingCard = nil
                    selectedTab = .myListings
                    FelToastCenter.shared.show("Listed \(card.title) for sale!")
                }
            } catch {
                await MainActor.run {
                    isListingInProgress = false
                    FelToastCenter.shared.show("Listing failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }
    
    private func deactivateListing(_ listing: ListActiveCardMarketListingsQuery.Data.CardMarketListing) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await DataConnect.socialConnector.deactivateCardMarketListingMutation.execute(
                    listingId: listing.id
                )
                try await refreshListings()
                
                await MainActor.run {
                    self.isLoading = false
                    FelToastCenter.shared.show("Listing cancelled successfully.")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    FelToastCenter.shared.show("Cancellation failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }
    
    private func executePurchase(listing: ListActiveCardMarketListingsQuery.Data.CardMarketListing) {
        guard let buyerId = mySqlUserId else {
            FelToastCenter.shared.show("User not registered in SQL database.", isError: true)
            return
        }
        
        guard viewModel.profile.evolutionShards >= listing.priceShards else {
            buyingCard = nil
            FelToastCenter.shared.show(FELEconomyLabels.insufficientShards + ". " + FELEconomyLabels.earnShardsHint, isError: true)
            return
        }
        
        isBuyingInProgress = true
        
        Task {
            do {
                let spent = listing.priceShards
                let cardId = listing.catalogCardId
                let royaltyShards = spent / 10 // 10% royalty

                // Fetch creator of the card from Data Connect to check if royalty applies
                let creatorResult = try await DataConnect.socialConnector.getCreatorCardCreatorQuery.execute(catalogCardId: cardId)
                if let creatorRow = creatorResult.data?.creatorCards.first,
                   let creatorUser = creatorRow.creator {
                    // Purchase with royalty
                    try await TrainingLabSocialBridge.shared.executeMarketplacePurchaseWithRoyalty(
                        listingId: listing.id,
                        buyerId: buyerId,
                        sellerId: listing.seller.id,
                        catalogCardId: cardId,
                        priceShards: spent,
                        creatorId: creatorUser.id,
                        royaltyShards: royaltyShards
                    )
                } else {
                    // Fallback to normal purchase (no creator tracked)
                    try await TrainingLabSocialBridge.shared.executeMarketplacePurchase(
                        listingId: listing.id,
                        buyerId: buyerId,
                        sellerId: listing.seller.id,
                        catalogCardId: cardId,
                        priceShards: spent
                    )
                }
                
                // Refresh list
                try await refreshListings()
                
                // Update local user profile state
                await MainActor.run {
                    viewModel.profile.evolutionShards -= spent
                    if !viewModel.profile.ownsCard(cardId) {
                        viewModel.profile.ownedCardIds.append(cardId)
                    }
                    SaveSystem.saveProfile(viewModel.profile)
                    
                    isBuyingInProgress = false
                    buyingCard = nil
                    
                    FelToastCenter.shared.show("Purchased card successfully!")
                }
            } catch {
                await MainActor.run {
                    isBuyingInProgress = false
                    buyingCard = nil
                    FelToastCenter.shared.show("Purchase failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    private func claimRoyaltiesFlow() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let claimId = UUID().uuidString
                let pendingAmount = viewModel.profile.pendingRoyaltyShards
                
                // Call Claim Royalties mutation
                try await TrainingLabSocialBridge.shared.claimRoyalties(claimId: claimId)
                
                // Update local user profile state
                await MainActor.run {
                    viewModel.profile.evolutionShards += pendingAmount
                    viewModel.profile.pendingRoyaltyShards = 0
                    SaveSystem.saveProfile(viewModel.profile)
                    
                    self.isLoading = false
                    FelToastCenter.shared.show("Claimed \(pendingAmount) royalties successfully!")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    FelToastCenter.shared.show("Claim failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }
}

