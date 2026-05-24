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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard
                    categoryPicker
                    itemsGrid
                    Text("Owned items are stored on this device. Shard spend is verified with the server; a cloud inventory table for shop cosmetics is not wired yet — reinstall can reset local ownership until that ships.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Shard Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    Text("Spend \(item.cost) shards on \(item.name)?")
                }
            }
            .alert("Insufficient Shards", isPresented: $showInsufficientShards) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Earn more shards through workouts and arena matches.")
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
                Text("YOUR BALANCE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.brandCyan)

                    Text("\(viewModel.profile.evolutionShards)")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            NeuralDriveOrb(value: Double(viewModel.profile.evolutionShards) / 100.0)
                .frame(width: 60, height: 60)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var categoryPicker: some View {
        HStack(spacing: 6) {
            ForEach(ShopItem.ShopCategory.allCases, id: \.rawValue) { cat in
                Button {
                    withAnimation(.snappy) { selectedCategory = cat }
                } label: {
                    Text(cat.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
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
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ShopItemCard(
                    item: item,
                    isPurchased: purchasedIds.contains(item.id),
                    canAfford: viewModel.profile.evolutionShards >= item.cost
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
            FelToastCenter.shared.show("Sign in with Firebase to verify shard purchases.", isError: true)
            return
        }
        do {
            try await TrainingLabSocialBridge.shared.recordShardLedgerDelta(
                deltaShards: -item.cost,
                reason: "shard_shop",
                referenceId: item.id
            )
            viewModel.profile.evolutionShards -= item.cost
            purchasedIds.insert(item.id)
            SaveSystem.saveProfile(viewModel.profile)
            savePurchased()
        } catch {
            FelToastCenter.shared.show("Could not verify purchase with the server.", isError: true)
        }
    }

    private let purchasedKey = "finalEvolution_purchased"

    private func loadPurchased() {
        if let data = UserDefaults.standard.data(forKey: purchasedKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            purchasedIds = ids
        }
    }

    private func savePurchased() {
        if let data = try? JSONEncoder().encode(purchasedIds) {
            UserDefaults.standard.set(data, forKey: purchasedKey)
        }
    }
}

struct ShopItemCard: View {
    let item: ShopItem
    let isPurchased: Bool
    let canAfford: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isPurchased ? Color.green.opacity(0.15) : Theme.brandBlue.opacity(0.1))
                            .frame(width: 36, height: 36)

                        Image(systemName: isPurchased ? "checkmark" : item.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isPurchased ? .green : Theme.brandBlue)
                    }

                    Spacer()
                }

                Text(item.name.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(item.description)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.brandCyan)

                    Text(isPurchased ? "OWNED" : "\(item.cost)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(isPurchased ? .green : (canAfford ? .white : .red))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPurchased ? Color.green.opacity(0.03) : Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isPurchased ? Color.green.opacity(0.15) : Theme.cardBorder, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchased)
    }
}
