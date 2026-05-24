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
                
                VStack(spacing: 0) {
                    // Shard Balance & Title Row
                    balanceHeader
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // Custom Navigation Tabs
                    tabSelector
                        .padding(.horizontal)
                        .padding(.top, 14)
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 16) {
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
                        .padding(16)
                    }
                }
                
                // Listing modal overlay
                if let card = listingCard {
                    listingDialog(for: card)
                }
                
                // Purchase confirmation modal overlay
                if let listing = buyingCard {
                    purchaseConfirmationDialog(for: listing)
                }
            }
            .navigationTitle("CREATOR MARKETPLACE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .onAppear {
                initializeMarketplace()
            }
        }
    }
    
    private var balanceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT SHARD DECK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.brandCyan)
                    Text("\(viewModel.profile.evolutionShards)")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("SHARDS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            Text("P2P ESCROW SYNCED")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.brandCyan.opacity(0.12))
                .foregroundStyle(Theme.brandCyan)
                .cornerRadius(4)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
            selectedTab = target
        } label: {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selectedTab == target ? Theme.brandCyan : Color.clear)
                .foregroundStyle(selectedTab == target ? .black : .white.opacity(0.7))
                .cornerRadius(8)
        }
    }
    
    private var loadingSpinner: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.brandCyan)
            Text("COMMUNICATING WITH SOCIAL DDC...")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func errorOverlay(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.red)
            Text("SQL CONNECTION SYNC FAULT")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
            Text(msg)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("RELOAD") {
                initializeMarketplace()
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
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
            Text("ACTIVE MARKET OFFERINGS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            let listings = activeListings.filter { listing in
                // Don't show listings sold by the current player
                guard let myId = mySqlUserId else { return true }
                return listing.seller.id != myId
            }
            
            if listings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("NO ACTIVE LISTINGS FOR SALE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Check back later or list one of your owned cards.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(listings) { listing in
                    marketListingCard(listing, isOwnListing: false)
                }
            }
        }
    }
    
    // MARK: - Sell Tab Content
    
    private var sellTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR OWNED CARDS AVAILABLE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            let ownedCards = CreatorCard.catalog.filter { viewModel.profile.ownsCard($0.id) }
            
            if ownedCards.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("YOU DON'T OWN ANY CREATOR CARDS YET")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
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
            Text("YOUR ACTIVE OFFERS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            let myListings = activeListings.filter { listing in
                guard let myId = mySqlUserId else { return false }
                return listing.seller.id == myId
            }
            
            if myListings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("NO ACTIVE SALES LISTINGS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(myListings) { listing in
                    marketListingCard(listing, isOwnListing: true)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private func marketListingCard(_ listing: ListActiveCardMarketListingsQuery.Data.CardMarketListing, isOwnListing: Bool) -> some View {
        let matchingCard = CreatorCard.catalog.first(where: { $0.id == listing.catalogCardId })
        let accentColor = matchingCard?.accentColor ?? Theme.brandCyan
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: matchingCard?.iconName ?? "crown")
                            .foregroundStyle(accentColor)
                        Text(matchingCard?.creatorName.uppercased() ?? "CREATOR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(accentColor)
                    }
                    
                    Text(matchingCard?.title ?? "Custom Creator Card")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                    
                    Text(matchingCard?.description ?? "Offers unique biomechanics style multipliers and physics modifiers.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                
                // Rarity tier or accent badge
                Text("P2P")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.12))
                    .foregroundStyle(accentColor)
                    .cornerRadius(4)
            }
            
            Divider()
                .background(Theme.cardBorder)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SELLER")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(listing.seller.username)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("PRICE")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(listing.priceShards) SHARDS")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    
                    if isOwnListing {
                        Button {
                            deactivateListing(listing)
                        } label: {
                            Text("CANCEL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .cornerRadius(6)
                        }
                    } else {
                        Button {
                            buyingCard = listing
                        } label: {
                            Text("BUY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.brandCyan)
                                .foregroundStyle(.black)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.slateCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
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
                Text("LIST CARD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
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
                Text("CREATE MARKET OFFER")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("CARD TO LIST")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(card.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("LISTING PRICE (SHARDS)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("Enter Shard Amount", text: $listingPriceString)
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
                            Text("CONFIRM LISTING")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
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
    
    private func purchaseConfirmationDialog(for listing: ListActiveCardMarketMarketListing) -> some View {
        let matchingCard = CreatorCard.catalog.first(where: { $0.id == listing.catalogCardId })
        
        return ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 18) {
                Text("BUY CREATOR CARD")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("CARD TITLE")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(matchingCard?.title ?? "Creator Card")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SELLER")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(listing.seller.username)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TOTAL COST")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(listing.priceShards) SHARDS")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                HStack(spacing: 12) {
                    Button("CANCEL") {
                        buyingCard = nil
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button {
                        executePurchase(listing: listing)
                    } label: {
                        HStack {
                            if isBuyingInProgress {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text("CONFIRM DECK SPEND")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
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
        guard viewModel.profile.evolutionShards >= listing.priceShards else {
            buyingCard = nil
            FelToastCenter.shared.show("Insufficient evolution shards.", isError: true)
            return
        }
        
        isBuyingInProgress = true
        
        Task {
            do {
                let spent = listing.priceShards
                let cardId = listing.catalogCardId
                
                // 1. Spend shards in escrow
                try await TrainingLabSocialBridge.shared.recordShardLedgerDelta(
                    deltaShards: -spent,
                    reason: "creator_card_purchase",
                    referenceId: cardId
                )
                
                // 2. Claim ownership in SQL
                try await TrainingLabSocialBridge.shared.claimCreatorCardOwnership(catalogCardId: cardId)
                
                // 3. Mark listing as deactivated
                _ = try await DataConnect.socialConnector.deactivateCardMarketListingMutation.execute(
                    listingId: listing.id
                )
                
                // Refresh list
                try await refreshListings()
                
                // 4. Update local user profile state
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
}

// Type alias helpers to avoid long generated nested namespaces in the SwiftUI code
typealias ListActiveCardMarketMarketListing = ListActiveCardMarketListingsQuery.Data.CardMarketListing
