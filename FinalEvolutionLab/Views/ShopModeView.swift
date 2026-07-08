import SwiftUI
import SceneKit

/// SHOP — the Final Evolution Lab creator-economy storefront, set inside the
/// Venice Ball Shop 3D environment. A slow idle-orbit SceneKit backdrop renders
/// the bundled `VenueVeniceBallShop` USDZ; over it, the shop composes the
/// creator-economy surfaces that already exist in the app (Creator Card
/// marketplace, showcase, critiques, creator hub, boost, vault, shard shop) as
/// discoverable sections. It is a pure SwiftUI destination — NOT routed through
/// GamePlayView's match scene path.
///
/// Fail-soft: if the venue USDZ is missing/corrupt, the backdrop falls back to a
/// tasteful cyan→purple gradient rather than crashing. Every composed surface
/// keeps its own navigation/dismiss behavior; the shop presents them as sheets
/// so their internal NavigationStacks are never double-wrapped.
struct ShopModeView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    /// Which creator-economy surface is currently presented over the backdrop.
    private enum Surface: String, Identifiable {
        case marketplace
        case critiqueRequest
        case creatorHub
        case boost
        case vault
        case shardShop
        var id: String { rawValue }
    }

    @State private var activeSurface: Surface?
    /// A featured card tapped from the storefront row → opens its detail sheet.
    @State private var featuredCard: CreatorCard?

    private var featuredCards: [CreatorCard] {
        Array(CreatorCard.catalog.prefix(6))
    }

    var body: some View {
        ZStack {
            // 3D backdrop (self-contained scene helper — does NOT touch
            // GameSceneFactory / karate scene builders).
            VeniceBallShopBackdrop()
                .ignoresSafeArea()

            // Legibility scrim over the 3D scene.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.55),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FELDesign.Space.lg) {
                    header
                    shardBalanceRow
                    featuredCardsRow
                    sectionsGrid
                    footerNote
                }
                .padding(.horizontal, FELDesign.Space.md)
                .padding(.top, FELDesign.Space.xxl)
                .padding(.bottom, FELDesign.Space.xxl)
            }
            .scrollIndicators(.hidden)
        }
        .background(FELDesign.Colors.ink)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ShopModeRoot")
        .sheet(item: $activeSurface) { surface in
            surfaceView(for: surface)
        }
        .sheet(item: $featuredCard) { card in
            NexusDeepLinkCardDetailView(card: card, viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
            Text("VENICE BALL SHOP")
                .font(FELDesign.Typography.micro)
                .tracking(FELDesign.Typography.microTracking)
                .foregroundStyle(FELDesign.Colors.cyan)

            Text("Creator Store")
                .font(FELDesign.Typography.display)
                .foregroundStyle(FELDesign.Colors.textPrimary)

            Text("Collect Creator Cards, request critiques, and publish your own — the full creator economy, one storefront.")
                .font(FELDesign.Typography.body)
                .foregroundStyle(FELDesign.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shardBalanceRow: some View {
        HStack(spacing: FELDesign.Space.sm) {
            HStack(spacing: 6) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FELDesign.Colors.cyan)
                Text("\(viewModel.profile.evolutionShards)")
                    .font(FELDesign.Typography.statLarge)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                Text("SHARDS")
                    .font(FELDesign.Typography.micro)
                    .tracking(FELDesign.Typography.microTracking)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }
            Spacer()
            Button {
                activeSurface = .shardShop
            } label: {
                Text("Get Shards")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.ink)
                    .padding(.horizontal, FELDesign.Space.md)
                    .padding(.vertical, FELDesign.Space.xs)
                    .background(Capsule().fill(FELDesign.Colors.cyan))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ShopGetShardsButton")
        }
        .padding(FELDesign.Space.md)
        .background(
            RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                .fill(FELDesign.Colors.surfaceRaised.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                        .strokeBorder(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                )
        )
    }

    // MARK: - Featured Creator Cards

    private var featuredCardsRow: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Text("FEATURED CREATOR CARDS")
                    .font(FELDesign.Typography.micro)
                    .tracking(FELDesign.Typography.microTracking)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                Spacer()
                Button("See all") { activeSurface = .marketplace }
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.cyan)
                    .accessibilityIdentifier("ShopSeeAllCardsButton")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FELDesign.Space.sm) {
                    ForEach(featuredCards) { card in
                        Button {
                            featuredCard = card
                        } label: {
                            featuredCardTile(card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func featuredCardTile(_ card: CreatorCard) -> some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                    .fill(
                        LinearGradient(
                            colors: [card.accentColor.opacity(0.55), card.accentColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: card.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 150, height: 110)

            Text(card.creatorName)
                .font(FELDesign.Typography.label)
                .foregroundStyle(FELDesign.Colors.textPrimary)
                .lineLimit(1)
            Text(card.title)
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textSecondary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(FELDesign.Colors.cyan)
                Text("\(card.costShards)")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
            }
        }
        .frame(width: 150, alignment: .leading)
        .padding(FELDesign.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                .fill(FELDesign.Colors.surface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                        .strokeBorder(card.accentColor.opacity(0.35), lineWidth: FELDesign.Stroke.hairline)
                )
        )
    }

    // MARK: - Sections grid

    private struct SectionSpec: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let surface: Surface
    }

    private var sections: [SectionSpec] {
        [
            SectionSpec(title: "Card Marketplace",
                        subtitle: "Browse, preview & buy Creator Cards",
                        icon: "square.grid.2x2.fill",
                        tint: FELDesign.Colors.cyan,
                        surface: .marketplace),
            SectionSpec(title: "Request a Critique",
                        subtitle: "Get expert feedback on your form",
                        icon: "person.crop.rectangle.badge.plus",
                        tint: FELDesign.Colors.purple,
                        surface: .critiqueRequest),
            SectionSpec(title: "Creator Hub",
                        subtitle: "Create & publish your own cards",
                        icon: "wand.and.stars",
                        tint: FELDesign.Colors.cyan,
                        surface: .creatorHub),
            SectionSpec(title: "Boost a Card",
                        subtitle: "Promote your creations",
                        icon: "arrow.up.forward.circle.fill",
                        tint: FELDesign.Colors.purple,
                        surface: .boost),
            SectionSpec(title: "Your Vault",
                        subtitle: "Owned cards & equipped skin",
                        icon: "lock.shield.fill",
                        tint: FELDesign.Colors.cyan,
                        surface: .vault),
            SectionSpec(title: "Shard Shop",
                        subtitle: "Top up your Evolution Shards",
                        icon: "diamond.fill",
                        tint: FELDesign.Colors.purple,
                        surface: .shardShop)
        ]
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: FELDesign.Space.sm),
        GridItem(.flexible(), spacing: FELDesign.Space.sm)
    ]

    private var sectionsGrid: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            Text("CREATOR ECONOMY")
                .font(FELDesign.Typography.micro)
                .tracking(FELDesign.Typography.microTracking)
                .foregroundStyle(FELDesign.Colors.textSecondary)

            LazyVGrid(columns: gridColumns, spacing: FELDesign.Space.sm) {
                ForEach(sections) { spec in
                    Button {
                        activeSurface = spec.surface
                    } label: {
                        sectionTile(spec)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ShopSection_\(spec.surface.rawValue)")
                }
            }
        }
    }

    private func sectionTile(_ spec: SectionSpec) -> some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
            Image(systemName: spec.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(spec.tint)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                        .fill(spec.tint.opacity(0.15))
                )

            Text(spec.title)
                .font(FELDesign.Typography.heading)
                .foregroundStyle(FELDesign.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(spec.subtitle)
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(FELDesign.Space.md)
        .background(
            RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                .fill(FELDesign.Colors.surfaceRaised.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                        .strokeBorder(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                )
        )
    }

    private var footerNote: some View {
        Text("Every Creator Card is original demo content. Shards are an in-app currency.")
            .font(FELDesign.Typography.caption)
            .foregroundStyle(FELDesign.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, FELDesign.Space.sm)
    }

    // MARK: - Surface presentation

    @ViewBuilder
    private func surfaceView(for surface: Surface) -> some View {
        switch surface {
        case .marketplace:
            CardMarketplaceView(viewModel: viewModel)
        case .critiqueRequest:
            CritiqueRequestView(viewModel: viewModel)
        case .creatorHub:
            NexusCreatorHubView(viewModel: viewModel)
        case .boost:
            NavigationStack { CreatorCardBoostView(viewModel: viewModel) }
        case .vault:
            NavigationStack { VaultView(viewModel: viewModel) }
        case .shardShop:
            ShardShopView(viewModel: viewModel)
        }
    }
}

// MARK: - Venice Ball Shop 3D backdrop

/// Self-contained SceneKit backdrop for the shop. Loads the bundled
/// `VenueVeniceBallShop` asset via `FELBundledAssets.venueNode` and presents it as
/// a slowly-rotating premium hero centerpiece with a three-point lighting rig.
/// Deliberately isolated from GameSceneFactory so it never conflicts with the
/// karate/game scene builders.
///
/// NOTE: the bundled asset is a Venice-beach *rainbow basketball* (a ~1.85m
/// sphere), not a storefront building, so it is framed as a floating hero prop
/// rather than an interior the camera orbits inside.
///
/// Fail-soft: if the USDZ cannot be loaded (nil node), it renders nothing and the
/// parent view's gradient scrim carries the look on its own.
private struct VeniceBallShopBackdrop: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = Self.makeScene()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling2X
        scnView.rendersContinuously = true
        scnView.isUserInteractionEnabled = false
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    @MainActor
    private static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 42
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 500
        cameraNode.camera?.wantsHDR = true
        // Fixed premium angle: hero object framed upper-right of the composition,
        // slightly above eye level, so the shop UI sits over open lower-left space.
        cameraNode.position = SCNVector3(0, 1.2, 9)
        cameraNode.eulerAngles = SCNVector3(-0.08, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Hero mesh — normalized to a compact size and spun on its own axis.
        // Fail-soft: only add if it loads.
        if let hero = FELBundledAssets.venueNode(.venueVeniceBallShop, footprint: 4.2) {
            // Frame it toward the upper area so the storefront cards read below it.
            hero.position = SCNVector3(0, 1.6, 0)
            hero.runAction(
                SCNAction.repeatForever(
                    SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 26)
                )
            )
            scene.rootNode.addChildNode(hero)
        }

        addLighting(to: scene)
        return scene
    }

    /// Premium venue lighting look kept local to the shop scene: warm key,
    /// cyan rim, soft purple fill, gentle ambient — matches the app's cyan/purple
    /// accent system without depending on any shared scene builder.
    @MainActor
    private static func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.24, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        key.light?.intensity = 900
        key.light?.castsShadow = true
        key.eulerAngles = SCNVector3(-0.9, 0.7, 0)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.color = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 1) // cyan
        rim.light?.intensity = 500
        rim.eulerAngles = SCNVector3(-0.2, .pi - 0.6, 0)
        scene.rootNode.addChildNode(rim)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.color = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1) // purple
        fill.light?.intensity = 350
        fill.position = SCNVector3(-8, 5, 6)
        scene.rootNode.addChildNode(fill)
    }
}
