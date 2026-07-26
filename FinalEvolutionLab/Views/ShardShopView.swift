import SwiftUI

struct ShardShopView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: ShopItem.ShopCategory = .outfit
    @State private var purchasedIds: Set<String> = []
    @State private var showPurchaseConfirm: ShopItem?
    @State private var showInsufficientShards = false
    @State private var appeared = false
    @State private var isPurchasing = false

    private let shopGridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    FELLumaShopViewport(
                        height: 210,
                        caption: "Evolution Shop",
                        subtitle: "Venice boardwalk · Luma scan",
                        neuralDrive: viewModel.effectiveMetrics.neuralDrive
                    )
                    .padding(.top, 4)

                    balanceCard
                    categoryPicker
                    itemsGrid

                    Text("Purchases sync to your account when signed in. Items you own stay on this device until cloud inventory ships.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle(FELEconomyLabels.shopTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FELPreviewLabel(text: FELPremiumCopy.Preview.economyStub)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Confirm Purchase", isPresented: Binding(
                get: { showPurchaseConfirm != nil },
                set: { if !$0 { showPurchaseConfirm = nil } }
            )) {
                Button("Cancel", role: .cancel) { showPurchaseConfirm = nil }
                Button("Purchase") {
                    if let item = showPurchaseConfirm {
                        completePurchase(item)
                    }
                }
                .disabled(isPurchasing)
            } message: {
                if let item = showPurchaseConfirm {
                    Text(FELEconomyLabels.purchasePrompt(itemName: item.name, cost: item.cost))
                }
            }
            .alert(FELEconomyLabels.insufficientShards, isPresented: $showInsufficientShards) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(FELEconomyLabels.earnShardsHint)
            }
            .onAppear {
                loadPurchased()
                withAnimation(.spring(response: 0.5)) { appeared = true }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
    }

    private var balanceCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(FELEconomyLabels.shardBalance.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.brandCyan)

                    Text("\(viewModel.profile.evolutionShards)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text(FELEconomyLabels.shards.lowercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            NeuralDriveOrb(value: Double(viewModel.profile.evolutionShards) / 100.0)
                .frame(width: 60, height: 60)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.brandCyan.opacity(0.35), Theme.brandCyan.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var categoryPicker: some View {
        HStack(spacing: 6) {
            ForEach(ShopItem.ShopCategory.allCases, id: \.rawValue) { cat in
                Button {
                    withAnimation(.snappy) { selectedCategory = cat }
                } label: {
                    Text(cat.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selectedCategory == cat ? Theme.brandBlue.opacity(0.2) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedCategory == cat ? Theme.brandBlue.opacity(0.5) : .clear, lineWidth: 1)
                        )
                        .foregroundStyle(selectedCategory == cat ? Theme.brandBlue : .secondary)
                }
            }
        }
    }

    private var itemsGrid: some View {
        let items = ShopCatalog.items(for: selectedCategory)
        return LazyVGrid(columns: shopGridColumns, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ShopItemCard(
                    item: item,
                    isPurchased: purchasedIds.contains(item.id),
                    canAfford: viewModel.profile.evolutionShards >= item.cost,
                    style: .premium
                ) {
                    handlePurchaseTap(item)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.spring(response: 0.4).delay(Double(index) * 0.06), value: appeared)
            }
        }
    }

    private func handlePurchaseTap(_ item: ShopItem) {
        if purchasedIds.contains(item.id) { return }
        if viewModel.profile.evolutionShards < item.cost {
            showInsufficientShards = true
            return
        }
        showPurchaseConfirm = item
    }

    private func completePurchase(_ item: ShopItem) {
        Task { @MainActor in
            await performVerifiedPurchase(item)
        }
    }

    /// Spendable shards require a Data Connect ledger receipt (GAME-45).
    private func performVerifiedPurchase(_ item: ShopItem) async {
        isPurchasing = true
        defer {
            isPurchasing = false
            showPurchaseConfirm = nil
        }
        TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
        guard FirebaseBootstrap.isConfigured else {
            FelToastCenter.shared.show("Sign in to verify shard purchases.", isError: true)
            return
        }
        do {
            try await TrainingLabSocialBridge.shared.recordShardLedgerDelta(
                deltaShards: -item.cost,
                reason: "shard_shop",
                referenceId: item.id
            )
            viewModel.profile.evolutionShards -= item.cost
            if !viewModel.profile.ownedCosmetics.contains(item.id) {
                viewModel.profile.ownedCosmetics.append(item.id)
            }
            purchasedIds.insert(item.id)
            SaveSystem.saveProfile(viewModel.profile)
            savePurchased()
        } catch {
            FelToastCenter.shared.show("Could not verify purchase with the server.", isError: true)
        }
    }

    private let purchasedKey = "finalEvolution_purchased"

    private func loadPurchased() {
        var ids: Set<String> = []
        if let data = UserDefaults.standard.data(forKey: purchasedKey),
           let decodedIds = try? JSONDecoder().decode(Set<String>.self, from: data) {
            ids = decodedIds
        }
        
        // Merge from profile's ownedCosmetics
        for cosmeticId in viewModel.profile.ownedCosmetics {
            ids.insert(cosmeticId)
        }
        
        // Also write back missing ones to profile just to stay perfectly in sync
        var profileModified = false
        for id in ids {
            if !viewModel.profile.ownedCosmetics.contains(id) {
                viewModel.profile.ownedCosmetics.append(id)
                profileModified = true
            }
        }
        
        if profileModified {
            SaveSystem.saveProfile(viewModel.profile)
        }
        
        purchasedIds = ids
    }

    private func savePurchased() {
        if let data = try? JSONEncoder().encode(purchasedIds) {
            UserDefaults.standard.set(data, forKey: purchasedKey)
        }
    }
}

struct ShopItemCard: View {
    enum Style {
        case standard
        case premium
    }

    let item: ShopItem
    let isPurchased: Bool
    let canAfford: Bool
    var style: Style = .standard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            switch style {
            case .standard:
                standardLayout
            case .premium:
                premiumLayout
            }
        }
        .buttonStyle(.plain)
        .disabled(isPurchased)
    }

    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            itemIcon(size: 36, iconSize: 14)
            Text(item.name.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(item.description)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            priceRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var premiumLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Theme.brandBlue.opacity(isPurchased ? 0.08 : 0.22),
                        Theme.brandCyan.opacity(isPurchased ? 0.04 : 0.08),
                        Theme.cardBackground,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 56)

                itemIcon(size: 40, iconSize: 16)
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(item.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                priceRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func itemIcon(size: CGFloat, iconSize: CGFloat) -> some View {
        HStack {
            ZStack {
                Circle()
                    .fill(isPurchased ? Color.green.opacity(0.15) : Theme.brandBlue.opacity(0.12))
                    .frame(width: size, height: size)

                Image(systemName: isPurchased ? "checkmark" : item.iconName)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(isPurchased ? .green : Theme.brandBlue)
            }
            Spacer()
        }
    }

    private var priceRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 9))
                .foregroundStyle(Theme.brandCyan)

            Text(isPurchased ? "Owned" : FELEconomyLabels.shardCost(item.cost))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isPurchased ? .green : (canAfford ? .white : .red))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: style == .premium ? 18 : 16, style: .continuous)
            .fill(isPurchased ? Color.green.opacity(0.02) : Theme.cardBackground.opacity(0.75))
            .overlay(
                RoundedRectangle(cornerRadius: style == .premium ? 18 : 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: isPurchased ? 
                                [Color.green.opacity(0.3), Color.green.opacity(0.05)] : 
                                [Theme.brandBlue.opacity(0.25), Theme.brandBlue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: style == .premium ? 1.0 : 0.5
                    )
            )
            .shadow(color: isPurchased ? Color.green.opacity(0.02) : Theme.brandBlue.opacity(0.03), radius: 6, x: 0, y: 3)
    }
}
