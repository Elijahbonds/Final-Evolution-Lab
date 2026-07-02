import SwiftUI

struct SystemScanCharacterEditorView: View {
    @Bindable var viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var activeTab: CustomizationTab = .avatar
    @State private var localConfig: AvatarSkinConfig = .default
    @State private var purchasedIds: Set<String> = []
    @State private var showPurchaseConfirm: ShopItem?
    @State private var showInsufficientShards = false
    @State private var isPurchasing = false

    // Sliders
    @State private var heightScale: Double = 1.0
    @State private var weightScale: Double = 1.0
    @State private var limbLength: Double = 1.0
    @State private var trailIntensity: Double = 0.3

    enum CustomizationTab: String, CaseIterable {
        case avatar = "Avatar"
        case wardrobe = "Wardrobe"
        case cards = "Creator Cards"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium mesh gradient background
                Theme.deepBlack
                    .ignoresSafeArea()
                Theme.meshGradient
                    .opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        if let card = CreatorCard.activeCard(for: viewModel.profile) {
                            HStack {
                                Text("CREATOR SKIN · \(card.creatorName.uppercased())")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(card.accentColor)
                                Spacer()
                                FELPreviewLabel(text: FELPremiumCopy.Preview.sceneKitStub)
                            }
                            .padding(.horizontal)
                        }
                        Character3DPreviewView(config: localConfig)
                            .frame(height: 280)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    // Navigation Tabs
                    HStack(spacing: 8) {
                        ForEach(CustomizationTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    activeTab = tab
                                }
                            } label: {
                                Text(tab.rawValue.uppercased())
                                    .font(FELTypography.mono(11, weight: .black))
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(activeTab == tab ? Theme.brandBlue.opacity(0.15) : Color.white.opacity(0.03))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(activeTab == tab ? Theme.brandBlue.opacity(0.6) : Color.clear, lineWidth: 1)
                                    )
                                    .foregroundStyle(activeTab == tab ? Theme.brandBlue : .secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 14)

                    // Scrollable Customization Controls
                    ScrollView {
                        VStack(spacing: 16) {
                            switch activeTab {
                            case .avatar:
                                avatarCustomizationSection
                            case .wardrobe:
                                wardrobeSection
                            case .cards:
                                creatorCardsSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Space for floating save button
                    }
                    .scrollIndicators(.hidden)
                }

                // Floating Save Button
                VStack {
                    Spacer()
                    Button {
                        saveChanges()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                            Text("SAVE CHARACTER CONFIG")
                        }
                        .font(FELTypography.mono(13, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Theme.brandBlue, Theme.brandCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Theme.brandBlue.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
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
            .navigationTitle("SYSTEM SCAN EDITOR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FELPreviewLabel(text: "HIFI_AVATAR")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(FELTypography.headline(15))
                    .foregroundStyle(Theme.brandBlue)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                // Load current configuration
                localConfig = viewModel.profile.avatarConfig
                heightScale = localConfig.heightScale
                weightScale = localConfig.weightScale
                limbLength = localConfig.limbLength
                trailIntensity = localConfig.trailIntensity
                loadPurchased()
            }
        }
    }

    // MARK: - Subsections

    private var avatarCustomizationSection: some View {
        VStack(spacing: 16) {
            // Skin Tone Picker
            VStack(alignment: .leading, spacing: 10) {
                Text("SKIN TONE")
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                HStack(spacing: 12) {
                    ForEach(AvatarSkinTone.allCases, id: \.self) { tone in
                        Button {
                            localConfig.skinTone = tone
                            updateAuraColor(for: tone)
                        } label: {
                            Circle()
                                .fill(Color(skinToneColor(tone)))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(localConfig.skinTone == tone ? .white : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: Color(skinToneColor(tone)).opacity(0.3), radius: 5)
                        }
                    }
                }
            }
            .nexusStudioCard()

            // Hairstyle Picker
            VStack(alignment: .leading, spacing: 10) {
                Text("HAIRSTYLE")
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(AvatarHairstyle.allCases, id: \.self) { style in
                        Button {
                            localConfig.hairstyle = style
                        } label: {
                            Text(style.rawValue.uppercased())
                                .font(FELTypography.mono(10, weight: .bold))
                                .foregroundStyle(localConfig.hairstyle == style ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(localConfig.hairstyle == style ? Theme.brandBlue : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(localConfig.hairstyle == style ? Color.clear : Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
            .nexusStudioCard()

            // Build Sliders
            VStack(alignment: .leading, spacing: 14) {
                Text("BIOMETRIC SCALES")
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                biometricSlider(label: "HEIGHT", value: $heightScale, range: 0.8...1.2, format: "%.0f%%") {
                    localConfig.heightScale = heightScale
                }

                biometricSlider(label: "BUILD", value: $weightScale, range: 0.8...1.2, format: "%.0f%%") {
                    localConfig.weightScale = weightScale
                }

                biometricSlider(label: "REACH (LIMBS)", value: $limbLength, range: 0.8...1.2, format: "%.0f%%") {
                    localConfig.limbLength = limbLength
                }

                biometricSlider(label: "AURA INTENSITY", value: $trailIntensity, range: 0.0...1.0, format: "%.0f%%") {
                    localConfig.trailIntensity = trailIntensity
                }
            }
            .nexusStudioCard()
        }
    }

    private var wardrobeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Glassmorphic Shard Balance card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FELEconomyLabels.shardBalance.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)

                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.brandCyan)

                        Text("\(viewModel.profile.evolutionShards)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())

                        Text(FELEconomyLabels.shards.lowercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                NeuralDriveOrb(value: Double(viewModel.profile.evolutionShards) / 100.0)
                    .frame(width: 44, height: 44)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardBackground.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.25), Theme.brandCyan.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.bottom, 4)

            Text("AVAILABLE OUTFITS")
                .font(FELTypography.mono(10, weight: .black))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            // Standard Outfits (Always available)
            VStack(alignment: .leading, spacing: 10) {
                Text("STANDARD ISSUE")
                    .font(FELTypography.mono(9, weight: .bold))
                    .foregroundStyle(.tertiary)

                ForEach(AvatarOutfitStyle.allCases.filter { !isShardShopOutfit($0) }, id: \.self) { outfit in
                    outfitRow(outfit: outfit, name: outfit.rawValue.capitalized, desc: standardOutfitDescription(outfit), isOwned: true)
                }
            }
            .nexusStudioCard()

            // Shard Shop Outfits (Require purchase)
            VStack(alignment: .leading, spacing: 10) {
                Text("SHARD SHOP EXCLUSIVES")
                    .font(FELTypography.mono(9, weight: .bold))
                    .foregroundStyle(.tertiary)

                ForEach(AvatarOutfitStyle.allCases.filter { isShardShopOutfit($0) }, id: \.self) { outfit in
                    let owned = purchasedIds.contains(shardShopItemId(for: outfit))
                    let name = shardShopItemName(for: outfit)
                    let description = shardShopItemDescription(for: outfit)
                    outfitRow(outfit: outfit, name: name, desc: description, isOwned: owned)
                }
            }
            .nexusStudioCard()
        }
    }

    private var creatorCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CREATOR CARDS INTEGRATION")
                .font(FELTypography.mono(10, weight: .black))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            // Active Card
            if let activeState = viewModel.profile.activeCreatorCard,
               let activeCard = CreatorCard.catalog.first(where: { $0.id == activeState.cardId }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: activeCard.iconName)
                            .font(.title3)
                            .foregroundStyle(activeCard.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ACTIVE BLUEPRINT")
                                .font(FELTypography.mono(8, weight: .black))
                                .foregroundStyle(activeCard.accentColor)
                            Text(activeCard.title.uppercased())
                                .font(FELTypography.mono(13, weight: .black))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button {
                            viewModel.clearCreatorCard()
                        } label: {
                            Text("UNEQUIP")
                                .font(FELTypography.mono(9, weight: .black))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // Stats Boosts
                    HStack(spacing: 12) {
                        statBoostBadge(label: "PRQ", value: "+\(activeCard.metricsBoost.prqScore)", color: Theme.brandBlue)
                        statBoostBadge(label: "NEURAL", value: "+\(activeCard.metricsBoost.neuralDrive)", color: Theme.elitePurple)
                        statBoostBadge(label: "READINESS", value: "+\(activeCard.metricsBoost.readinessScore)", color: Theme.brandCyan)
                    }

                    // Movement Signature
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MOVEMENT SIGNATURE")
                            .font(FELTypography.mono(8, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack {
                            Label(activeCard.movementSignature.style.rawValue.uppercased(), systemImage: "waveform.path.ecg")
                                .font(FELTypography.mono(10, weight: .bold))
                                .foregroundStyle(activeCard.accentColor)
                            Spacer()
                            Text(String(format: "APEX: %.1fx", activeCard.movementSignature.jumpApex))
                                .font(FELTypography.mono(9, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .nexusStudioCard()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.badge.a.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("NO CREATOR CARD EQUIPPED")
                        .font(FELTypography.mono(11, weight: .black))
                        .foregroundStyle(.white)
                    Text("Equip a Creator Card to apply performance boosts and custom movement signatures.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .nexusStudioCard()
            }

            // Owned Cards List
            Text("OWNED CARDS")
                .font(FELTypography.mono(9, weight: .bold))
                .foregroundStyle(.tertiary)

            let ownedCards = CreatorCard.catalog.filter { viewModel.profile.ownsCard($0.id) }
            if ownedCards.isEmpty {
                VStack {
                    Text("NO CREATOR CARDS OWNED")
                        .font(FELTypography.mono(10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("Visit the Card Marketplace to unlock blueprints.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .nexusStudioCard()
            } else {
                ForEach(ownedCards) { card in
                    let isActive = viewModel.profile.activeCreatorCard?.cardId == card.id
                    Button {
                        if isActive {
                            viewModel.clearCreatorCard()
                        } else {
                            viewModel.applyCreatorCard(card)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: card.iconName)
                                .font(.title3)
                                .foregroundStyle(card.accentColor)
                                .frame(width: 36, height: 36)
                                .background(card.accentColor.opacity(0.1))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.title.uppercased())
                                    .font(FELTypography.mono(11, weight: .black))
                                    .foregroundStyle(.white)
                                Text(card.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isActive ? Theme.brandBlue : .secondary)
                        }
                        .padding(12)
                        .background(Color.white.opacity(isActive ? 0.06 : 0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isActive ? Theme.brandBlue.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func biometricSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, onChange: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(FELTypography.mono(9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue * 100))
                    .font(FELTypography.mono(10, weight: .black))
                    .foregroundStyle(Theme.brandBlue)
            }

            Slider(value: value, in: range)
                .tint(Theme.brandBlue)
                .onChange(of: value.wrappedValue) { _, _ in
                    onChange()
                }
        }
    }

    private func outfitRow(outfit: AvatarOutfitStyle, name: String, desc: String, isOwned: Bool) -> some View {
        let isEquipped = localConfig.outfitStyle == outfit

        return HStack(spacing: 12) {
            Image(systemName: "tshirt.fill")
                .font(.title3)
                .foregroundStyle(isOwned ? Theme.brandBlue : .secondary)
                .frame(width: 36, height: 36)
                .background(isOwned ? Theme.brandBlue.opacity(0.1) : Color.white.opacity(0.04))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(name.uppercased())
                    .font(FELTypography.mono(11, weight: .black))
                    .foregroundStyle(isOwned ? .white : .secondary)
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isOwned {
                Button {
                    localConfig.outfitStyle = outfit
                } label: {
                    Text(isEquipped ? "EQUIPPED" : "EQUIP")
                        .font(FELTypography.mono(9, weight: .black))
                        .foregroundStyle(isEquipped ? .black : Theme.brandBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isEquipped ? Theme.brandBlue : Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }
                .disabled(isEquipped)
            } else {
                if let item = ShopCatalog.items.first(where: { $0.id == shardShopItemId(for: outfit) }) {
                    Button {
                        handleDirectBuyTap(item)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.brandCyan)
                            Text("\(item.cost)")
                                .font(FELTypography.mono(10, weight: .black))
                            Text("BUY")
                                .font(FELTypography.mono(9, weight: .black))
                                .padding(.leading, 2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Theme.brandBlue, Theme.brandCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("LOCKED")
                            .font(FELTypography.mono(9, weight: .black))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isEquipped ? Theme.brandBlue.opacity(0.08) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isEquipped ? 
                            [Theme.brandBlue.opacity(0.4), Theme.brandBlue.opacity(0.1)] : 
                            [Color.white.opacity(0.1), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: isEquipped ? Theme.brandBlue.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 4)
    }

    private func statBoostBadge(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(FELTypography.mono(8, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(FELTypography.mono(9, weight: .black))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Helper Functions

    private func updateAuraColor(for tone: AvatarSkinTone) {
        switch tone {
        case .cyan:
            localConfig.auraColorR = 0.0
            localConfig.auraColorG = 0.83
            localConfig.auraColorB = 1.0
        case .blue:
            localConfig.auraColorR = 0.2
            localConfig.auraColorG = 0.5
            localConfig.auraColorB = 1.0
        case .green:
            localConfig.auraColorR = 0.2
            localConfig.auraColorG = 1.0
            localConfig.auraColorB = 0.4
        case .elitePurple:
            localConfig.auraColorR = 0.6
            localConfig.auraColorG = 0.2
            localConfig.auraColorB = 1.0
        case .orange:
            localConfig.auraColorR = 1.0
            localConfig.auraColorG = 0.5
            localConfig.auraColorB = 0.0
        }
    }

    private func skinToneColor(_ tone: AvatarSkinTone) -> Color {
        switch tone {
        case .cyan: return Theme.brandBlue
        case .blue: return Theme.flightBlue
        case .green: return Theme.neonGreen
        case .elitePurple: return Theme.elitePurple
        case .orange: return Color.orange
        }
    }

    private func isShardShopOutfit(_ outfit: AvatarOutfitStyle) -> Bool {
        switch outfit {
        case .neon, .shadow, .chrome, .gold:
            return true
        default:
            return false
        }
    }

    private func shardShopItemId(for outfit: AvatarOutfitStyle) -> String {
        switch outfit {
        case .neon: return "outfit_neon"
        case .shadow: return "outfit_shadow"
        case .chrome: return "outfit_chrome"
        case .gold: return "outfit_gold"
        default: return ""
        }
    }

    private func shardShopItemName(for outfit: AvatarOutfitStyle) -> String {
        switch outfit {
        case .neon: return "Neon Flux"
        case .shadow: return "Shadow Elite"
        case .chrome: return "Chrome V"
        case .gold: return "Gold Standard"
        default: return ""
        }
    }

    private func shardShopItemDescription(for outfit: AvatarOutfitStyle) -> String {
        switch outfit {
        case .neon: return "Electric cyan skin with pulse effects"
        case .shadow: return "Dark matte finish with ember accents"
        case .chrome: return "Reflective metallic with blue highlights"
        case .gold: return "Premium gold plated avatar"
        default: return ""
        }
    }

    private func standardOutfitDescription(_ outfit: AvatarOutfitStyle) -> String {
        switch outfit {
        case .standard: return "Standard issue athletic wear"
        case .developing: return "Developing tier kinetic suit"
        case .flight: return "High-altitude flight mechanics suit"
        case .elite: return "Elite tier pro-performance suit"
        default: return ""
        }
    }

    private func loadPurchased() {
        var ids: Set<String> = []
        if let data = UserDefaults.standard.data(forKey: "finalEvolution_purchased"),
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

    private func handleDirectBuyTap(_ item: ShopItem) {
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
            FelToastCenter.shared.show("Unlocked \(item.name)!")
        } catch {
            FelToastCenter.shared.show("Could not verify purchase with the server.", isError: true)
        }
    }

    private func savePurchased() {
        if let data = try? JSONEncoder().encode(purchasedIds) {
            UserDefaults.standard.set(data, forKey: "finalEvolution_purchased")
        }
    }

    private func saveChanges() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Save the updated configuration to the profile
        viewModel.profile.avatarConfig = localConfig
        
        // Also update the system scan configuration if it exists
        if var scan = viewModel.profile.systemScan {
            scan.avatarConfig = localConfig
            viewModel.profile.systemScan = scan
        }
        
        // Persist the profile
        SaveSystem.saveProfile(viewModel.profile)
        
        dismiss()
    }
}
