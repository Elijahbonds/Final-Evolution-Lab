import SwiftUI
import SceneKit

/// A premium, glassmorphic UI where creators can upload competition animations,
/// mint them into Creator Cards with stats boosts and Masterclass links, and track their royalty earnings.
struct NexusCreatorHubView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: LabViewModel
    
    // View state
    @State private var selectedTab: HubTab = .animations
    @State private var selectedAnimation: NexusAnimationAsset? = nil
    
    // Minting Flow state
    @State private var mintingAnimation: NexusAnimationAsset? = nil
    @State private var cardTitle: String = ""
    @State private var cardDescription: String = ""
    @State private var shardCost: Int = 500
    @State private var masterclassUrl: String = "https://finalevolutiongroup.com/masterclass/"
    
    // Stats Boost sliders
    @State private var prqBoost: Double = 10
    @State private var verticalBoost: Double = 15
    @State private var neuralBoost: Double = 10
    @State private var efficiencyBoost: Double = 5
    
    // Toast state
    @State private var toastMessage: String? = nil
    @State private var isErrorToast = false
    
    enum HubTab {
        case animations
        case mint
        case dashboard
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.4).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header banner
                        FELLumaShopViewport(
                            height: 160,
                            caption: "CREATOR STUDIO",
                            subtitle: "Mint, monetize, and share your athletic data",
                            accent: Theme.brandCyan,
                            neuralDrive: viewModel.effectiveMetrics.neuralDrive
                        )
                        .padding(.top, 4)
                        
                        // Tab Selector
                        tabSelector
                        
                        // Tab Content
                        switch selectedTab {
                        case .animations:
                            animationsTabContent
                        case .mint:
                            mintTabContent
                        case .dashboard:
                            dashboardTabContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                
                // Toast overlay
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(isErrorToast ? .white : .black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isErrorToast ? Color.red : Theme.neonGreen)
                            .clipShape(Capsule())
                            .shadow(radius: 8)
                            .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .navigationTitle("Creator Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                        .font(.system(.body, design: .monospaced))
                }
                ToolbarItem(placement: .principal) {
                    FELPreviewLabel(text: "NEXUS CREATOR PIPELINE")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 4) {
            tabButton(title: "Animations", target: .animations, icon: "figure.run")
            tabButton(title: "Mint Card", target: .mint, icon: "plus.rectangle.on.folder")
            tabButton(title: "Dashboard", target: .dashboard, icon: "chart.bar.xaxis")
        }
        .padding(4)
        .background(Theme.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func tabButton(title: String, target: HubTab, icon: String) -> some View {
        Button {
            withAnimation(.snappy) { selectedTab = target }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selectedTab == target ? Theme.brandCyan : Color.clear)
            .foregroundStyle(selectedTab == target ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Animations Tab
    
    private var animationsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("MY COMPETITION ANIMATIONS")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                
                Spacer()
                
                Button(action: simulateAnimationUpload) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("SIMULATE UPLOAD")
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.brandCyan.opacity(0.15))
                    .foregroundStyle(Theme.brandCyan)
                    .clipShape(Capsule())
                }
            }
            
            if viewModel.profile.competitionAnimations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("No competition animations uploaded yet.")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    Text("Capture your movements in the field or use the simulation button above to upload a .nexusanim.json file from a real competition.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
            } else {
                // 3D SceneKit Preview Box
                VStack(alignment: .leading, spacing: 8) {
                    Text("3D MANNEQUIN PREVIEW")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.5))
                            .frame(height: 200)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
                        
                        if let selected = selectedAnimation {
                            CourtSceneView(
                                neuralDrive: viewModel.profile.metrics.neuralDrive,
                                verticalPotential: viewModel.profile.metrics.verticalPotential,
                                auraLevel: .baseline,
                                movementSignature: viewModel.activeMovementSignature,
                                onDunkTriggered: {},
                                dunkPhase: .idle,
                                selectedTrick: .windmill,
                                sprintCharge: 0,
                                jumpHeight: 0,
                                rotationProgress: 0,
                                selectedAnimation: selected
                            )
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.title)
                                    .foregroundStyle(Theme.brandCyan.opacity(0.5))
                                Text("SELECT AN ANIMATION TO PREVIEW IN 3D")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                
                // List of Animations
                VStack(spacing: 10) {
                    ForEach(viewModel.profile.competitionAnimations) { anim in
                        Button {
                            selectedAnimation = anim
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(anim.header.title.uppercased())
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                    
                                    HStack(spacing: 8) {
                                        Text(anim.header.competitionName)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text("•")
                                            .foregroundStyle(.secondary)
                                        Text(anim.header.category.uppercased())
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Theme.brandCyan)
                                    }
                                }
                                Spacer()
                                
                                Button {
                                    mintingAnimation = anim
                                    cardTitle = anim.header.title
                                    cardDescription = "Custom Creator Card featuring my signature \(anim.header.title)!"
                                    selectedTab = .mint
                                } label: {
                                    Text("MINT CARD")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.neonGreen)
                                        .foregroundStyle(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedAnimation?.id == anim.id ? Theme.brandCyan.opacity(0.5) : Theme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Mint Tab
    
    private var mintTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MINT CREATOR CARD")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)
            
            // Selected Animation Card Info
            VStack(alignment: .leading, spacing: 12) {
                Text("SOURCE ANIMATION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                
                if let anim = mintingAnimation ?? viewModel.profile.competitionAnimations.first {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(anim.header.title.uppercased())
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                            Text(anim.header.competitionName)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(anim.header.category.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.brandCyan.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.slateCard))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                    .onAppear {
                        if mintingAnimation == nil {
                            mintingAnimation = anim
                            cardTitle = anim.header.title
                            cardDescription = "Custom Creator Card featuring my signature \(anim.header.title)!"
                        }
                    }
                } else {
                    Text("Please select or upload an animation first.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
                }
            }
            
            if mintingAnimation != nil {
                // Form Fields
                VStack(alignment: .leading, spacing: 16) {
                    // Card Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CARD TITLE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("Enter card title", text: $cardTitle)
                            .font(.system(size: 13, design: .monospaced))
                            .padding()
                            .background(Theme.slateCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                    }
                    
                    // Card Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CARD DESCRIPTION")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("Enter card description", text: $cardDescription)
                            .font(.system(size: 13, design: .monospaced))
                            .padding()
                            .background(Theme.slateCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                    }
                    
                    // Shard Cost
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SHARD COST")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(shardCost) SHARDS")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                        }
                        Stepper(value: $shardCost, in: 100...2000, step: 50) {
                            Text("Adjust marketplace price")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Theme.slateCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                    }
                    
                    // Masterclass Link
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MASTERCLASS / PRODUCT LINK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("URL (e.g. finalevolutiongroup.com/masterclass/...)", text: $masterclassUrl)
                            .font(.system(size: 12, design: .monospaced))
                            .padding()
                            .background(Theme.slateCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                    }
                    
                    // Stats Boosts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("STATS BOOSTS (MINTED CARD BONUSES)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        VStack(spacing: 10) {
                            boostSlider(title: "PRQ Score Boost", value: $prqBoost, maxVal: 20, color: Theme.brandBlue)
                            boostSlider(title: "Vertical Potential Boost", value: $verticalBoost, maxVal: 30, color: Theme.neonGreen)
                            boostSlider(title: "Neural Drive Boost", value: $neuralBoost, maxVal: 25, color: Theme.elitePurple)
                            boostSlider(title: "Efficiency Score Boost", value: $efficiencyBoost, maxVal: 15, color: .orange)
                        }
                        .padding()
                        .background(Theme.slateCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                    }
                }
                
                // Mint Action Button
                Button(action: mintCreatorCard) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("MINT CREATOR CARD")
                            .font(.system(.headline, design: .monospaced, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.neonGreen)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Theme.neonGreen.opacity(0.3), radius: 10)
                }
                .padding(.top, 10)
            }
        }
    }
    
    private func boostSlider(title: String, value: Binding<Double>, maxVal: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("+\(Int(value.wrappedValue))")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }
            Slider(value: value, in: 0...maxVal, step: 1)
                .tint(color)
        }
    }
    
    // MARK: - Dashboard Tab
    
    private var dashboardTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ROYALTY EARNINGS DASHBOARD")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                
                Spacer()
                
                Button(action: simulateCardSale) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("SIMULATE SALE")
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.neonGreen.opacity(0.15))
                    .foregroundStyle(Theme.neonGreen)
                    .clipShape(Capsule())
                }
            }

            creatorIPShowcaseSection
            
            // Earnings Stats Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                dashboardStatCard(title: "TOTAL SALES", value: "\(viewModel.profile.totalRoyaltySales)", icon: "cart.fill", color: Theme.brandBlue)
                dashboardStatCard(title: "ACTIVE LISTINGS", value: "\(viewModel.profile.mintedCreatorCards.count)", icon: "tag.fill", color: .orange)
                dashboardStatCard(title: "TOTAL ROYALTIES", value: "\(viewModel.profile.totalRoyaltyEarnings) Shards", icon: "sparkles", color: Theme.elitePurple)
                dashboardStatCard(title: "PENDING ROYALTIES", value: "\(viewModel.profile.pendingRoyaltyShards) Shards", icon: "diamond.fill", color: Theme.brandCyan)
            }
            
            // Claim Royalties Button
            if viewModel.profile.pendingRoyaltyShards > 0 {
                Button(action: claimRoyalties) {
                    HStack {
                        Image(systemName: "diamond.fill")
                        Text("CLAIM PENDING ROYALTIES (+\(viewModel.profile.pendingRoyaltyShards) SHARDS)")
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandCyan)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Theme.brandCyan.opacity(0.3), radius: 8)
                }
            }
            
            // Minted Cards List
            VStack(alignment: .leading, spacing: 10) {
                Text("MY MINTED CREATOR CARDS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                
                if viewModel.profile.mintedCreatorCards.isEmpty {
                    Text("No minted Creator Cards yet. Go to the Mint tab to create your first card!")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.02)))
                } else {
                    ForEach(viewModel.profile.mintedCreatorCards) { card in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.title.uppercased())
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                    Text(card.description)
                                        .font(.system(size: 9, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(card.costShards) Shards")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(Theme.brandCyan)
                            }
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("MASTERCLASS URL")
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Link(destination: URL(string: card.masterclassUrl) ?? URL(string: "https://finalevolutiongroup.com")!) {
                                        Text(card.masterclassUrl)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(Theme.brandBlue)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("SALES / EARNINGS")
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("\(card.totalSales) sales / \(card.royaltyEarnings) shards")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Theme.neonGreen)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Creator IP Showcase (masterclass / IMDb / product / bio)

    private var creatorIPShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CREATOR IP SHOWCASE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)

            ForEach(CreatorCard.catalog.filter { $0.masterclassURL != nil || $0.productURL != nil || $0.imdbURL != nil }.prefix(4)) { card in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: card.iconName)
                            .foregroundStyle(card.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.creatorName.uppercased())
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                            Text(card.title)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.profile.activeCreatorCard?.cardId == card.id {
                            Text("EQUIPPED")
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Capsule().fill(Theme.neonGreen))
                        }
                    }

                    if let bio = card.creatorBio {
                        Text(bio)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        if let url = card.masterclassURL {
                            ipLinkChip(title: "Masterclass", url: url, icon: "play.rectangle.fill")
                        }
                        if let url = card.imdbURL {
                            ipLinkChip(title: "IMDb", url: url, icon: "film.stack")
                        }
                        if let url = card.productURL {
                            ipLinkChip(title: "Product", url: url, icon: "bag.fill")
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(card.accentColor.opacity(0.25), lineWidth: 1))
            }
        }
        .accessibilityIdentifier("CreatorIPShowcase")
    }

    private func ipLinkChip(title: String, url: String, icon: String) -> some View {
        Link(destination: URL(string: url) ?? URL(string: "https://finalevolutiongroup.com")!) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
            }
            .foregroundStyle(Theme.brandCyan)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Capsule().fill(Theme.brandCyan.opacity(0.12)))
        }
    }
    
    private func dashboardStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
    }
    
    // MARK: - Core Logic & Simulation handlers
    
    private func simulateAnimationUpload() {
        let presets = [
            ("Double-Clutch Windmill", "Dunk", "WDA Championship 2026"),
            ("Free-Throw Line Glide", "Dunk", "Slam Dunk Contest 2026"),
            ("360 Eastbay Spike", "Dunk", "WDA Global Finals"),
            ("Stella Adler Monologue", "Drama/Artistic", "Stella Adler Studio"),
            ("Double Kick Kick", "Kick", "World Martial Arts Expo")
        ]
        
        let randomPreset = presets.randomElement()!
        
        if let result = NexusCompetitionAnimationUploader.shared.uploadAnimation(
            title: randomPreset.0,
            competitionName: randomPreset.2,
            category: randomPreset.1,
            jsonPayload: "",
            to: viewModel.profile
        ) {
            viewModel.profile = result.0
            SaveSystem.saveProfile(viewModel.profile)
            selectedAnimation = result.1
            showToast("Successfully uploaded \(randomPreset.0)!")
        }
    }
    
    private func mintCreatorCard() {
        guard let anim = mintingAnimation else { return }
        
        let stats = PerformanceMetrics(
            efficiencyScore: Double(efficiencyBoost),
            prqScore: Double(prqBoost),
            readinessScore: 5,
            verticalPotential: Double(verticalBoost),
            neuralDrive: Double(neuralBoost),
            currentOutfit: "creator_minted_\(anim.id)"
        )
        
        let newCard = MintedCreatorCard(
            id: "card_\(UUID().uuidString.prefix(8))",
            animationId: anim.id,
            title: cardTitle,
            description: cardDescription,
            costShards: shardCost,
            masterclassUrl: masterclassUrl,
            statsBoost: stats
        )
        
        viewModel.profile.mintedCreatorCards.append(newCard)
        SaveSystem.saveProfile(viewModel.profile)
        
        showToast("Successfully minted \(cardTitle)!")
        
        // Reset form
        mintingAnimation = nil
        cardTitle = ""
        cardDescription = ""
        shardCost = 500
        masterclassUrl = "https://finalevolutiongroup.com/masterclass/"
        
        // Switch to dashboard
        selectedTab = .dashboard
    }
    
    private func simulateCardSale() {
        guard !viewModel.profile.mintedCreatorCards.isEmpty else {
            showToast("Mint a Creator Card first to simulate sales!", isError: true)
            return
        }
        
        let randomIndex = Int.random(in: 0..<viewModel.profile.mintedCreatorCards.count)
        var card = viewModel.profile.mintedCreatorCards[randomIndex]
        
        // Calculate 10% royalties
        let royalties = Int(Double(card.costShards) * 0.10)
        
        card.totalSales += 1
        card.royaltyEarnings += royalties
        
        viewModel.profile.mintedCreatorCards[randomIndex] = card
        viewModel.profile.totalRoyaltySales += 1
        viewModel.profile.totalRoyaltyEarnings += royalties
        viewModel.profile.pendingRoyaltyShards += royalties
        
        SaveSystem.saveProfile(viewModel.profile)
        
        showToast("Simulated sale of \(card.title)! Earned \(royalties) Shards.")
    }
    
    private func claimRoyalties() {
        let claimed = viewModel.profile.pendingRoyaltyShards
        guard claimed > 0 else { return }
        
        viewModel.profile.evolutionShards += claimed
        viewModel.profile.pendingRoyaltyShards = 0
        
        SaveSystem.saveProfile(viewModel.profile)
        
        showToast("Claimed \(claimed) Shards from royalties!")
    }
    
    private func showToast(_ message: String, isError: Bool = false) {
        toastMessage = message
        isErrorToast = isError
        UINotificationFeedbackGenerator().notificationOccurred(isError ? .error : .success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
