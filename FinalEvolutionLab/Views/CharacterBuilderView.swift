import SwiftUI

// MARK: — CharacterBuilderView

struct CharacterBuilderView: View {
    let scan: SystemScanResult?
    let userId: String
    let displayName: String
    let onSave: (PlayerAvatarConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var config: PlayerAvatarConfig
    @State private var activeSection: BuilderSection = .face
    @State private var appeared = false

    private enum BuilderSection: String, CaseIterable {
        case face   = "FACE"
        case style  = "STYLE"
        case outfit = "OUTFIT"
        case gear   = "GEAR"
    }

    // Hair color palette (hex strings)
    private let hairColors: [(String, Color)] = [
        ("#1A1A1A", .black),
        ("#4A2912", Color(red: 0.29, green: 0.16, blue: 0.07)),
        ("#8D5524", Color(red: 0.55, green: 0.33, blue: 0.14)),
        ("#C5A028", Color(red: 0.77, green: 0.63, blue: 0.16)),
        ("#F4B942", Color(red: 0.96, green: 0.73, blue: 0.26)),
        ("#A0A0A0", Color(red: 0.63, green: 0.63, blue: 0.63)),
    ]

    private let jerseySwatches: [(String, Color)] = [
        ("#00E5FF", Color(red: 0, green: 0.898, blue: 1)),
        ("#8B5CF6", Color(red: 0.545, green: 0.361, blue: 0.965)),
        ("#00F5A0", Color(red: 0, green: 0.961, blue: 0.627)),
        ("#FF3B30", Color(red: 1, green: 0.231, blue: 0.188)),
        ("#FF9500", Color(red: 1, green: 0.584, blue: 0)),
        ("#FFFFFF", .white),
        ("#1A1A24", Color(red: 0.102, green: 0.102, blue: 0.141)),
        ("#2C2C54", Color(red: 0.173, green: 0.173, blue: 0.329)),
    ]

    private let shoeSwatches: [(String, Color)] = [
        ("#FFFFFF", .white),
        ("#000000", .black),
        ("#00E5FF", Color(red: 0, green: 0.898, blue: 1)),
        ("#FF3B30", Color(red: 1, green: 0.231, blue: 0.188)),
        ("#8B5CF6", Color(red: 0.545, green: 0.361, blue: 0.965)),
        ("#FF9500", Color(red: 1, green: 0.584, blue: 0)),
    ]

    init(scan: SystemScanResult?, userId: String, displayName: String, onSave: @escaping (PlayerAvatarConfig) -> Void) {
        self.scan = scan
        self.userId = userId
        self.displayName = displayName
        self.onSave = onSave
        let initial: PlayerAvatarConfig
        if let scan = scan {
            initial = PlayerAvatarConfig.fromScan(scan, userId: userId, displayName: displayName)
        } else {
            initial = PlayerAvatarConfig.makeDefault(userId: userId, displayName: displayName)
        }
        _config = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.deepBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Preview + section tabs
                    avatarPreviewSection
                        .frame(height: 200)
                    sectionTabBar
                    // Section scroll
                    ScrollView {
                        Group {
                            switch activeSection {
                            case .face:   faceSection
                            case .style:  styleSection
                            case .outfit: outfitSection
                            case .gear:   gearSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }

                // Fixed save button
                saveButtonBar
            }
            .navigationTitle("BUILD AVATAR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
        }
    }

    // MARK: — Avatar Preview

    private var avatarPreviewSection: some View {
        ZStack {
            // Aura glow backdrop
            RadialGradient(
                colors: [
                    Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB).opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 120
            )
            .ignoresSafeArea(edges: .top)

            HStack(spacing: 24) {
                // Canvas figure
                Canvas { ctx, size in
                    drawAvatarFigure(ctx: ctx, size: size)
                }
                .frame(width: 100, height: 180)

                // Stats sidebar
                VStack(alignment: .leading, spacing: 8) {
                    avatarStatChip(label: "FACE", value: config.facePreset.displayName)
                    avatarStatChip(label: "TIER", value: config.outfitTier.displayName.uppercased())
                    avatarStatChip(label: "MODEL",
                                   value: config.usePersonalModel ? "EB PERSONAL" : "GENERATED")
                    if let scan = scan {
                        avatarStatChip(label: "PRQ",
                                       value: String(format: "%.0f", scan.prqScore))
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : 12)
            }
            .padding(.horizontal, 24)
        }
    }

    private func drawAvatarFigure(ctx: GraphicsContext, size: CGSize) {
        let skinColor    = Color(hex: config.skinTone.hexValue) ?? Color(red: 0.55, green: 0.33, blue: 0.14)
        let jerseyColor  = Color(hex: config.jerseyColorHex) ?? Theme.brandCyan
        let shortsColor  = Color(hex: config.shortsColorHex) ?? Color(red: 0.1, green: 0.1, blue: 0.14)
        let shoeColor    = Color(hex: config.shoeColorHex) ?? .white
        let auraColor    = Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)

        let cx = size.width / 2
        let scale = config.heightScale

        // Aura particle ring at feet
        let auraPath = Path(ellipseIn: CGRect(x: cx - 36, y: size.height - 26, width: 72, height: 18))
        ctx.fill(auraPath, with: .color(auraColor.opacity(0.25)))

        // Shoes
        let leftShoe  = Path(roundedRect: CGRect(x: cx - 28, y: size.height - 22, width: 22, height: 10), cornerRadius: 4)
        let rightShoe = Path(roundedRect: CGRect(x: cx + 6,  y: size.height - 22, width: 22, height: 10), cornerRadius: 4)
        ctx.fill(leftShoe,  with: .color(shoeColor))
        ctx.fill(rightShoe, with: .color(shoeColor))

        // Legs (shorts)
        let legH = 46 * scale
        let legTop = size.height - 22 - legH
        let leftLeg  = Path(roundedRect: CGRect(x: cx - 22, y: legTop, width: 18, height: legH), cornerRadius: 6)
        let rightLeg = Path(roundedRect: CGRect(x: cx + 4,  y: legTop, width: 18, height: legH), cornerRadius: 6)
        ctx.fill(leftLeg,  with: .color(shortsColor))
        ctx.fill(rightLeg, with: .color(shortsColor))

        // Torso (jersey)
        let torsoH = 58 * scale
        let torsoY = legTop - torsoH + 6
        let torso = Path(roundedRect: CGRect(x: cx - 26, y: torsoY, width: 52, height: torsoH), cornerRadius: 10)
        ctx.fill(torso, with: .color(jerseyColor.opacity(0.9)))

        // Arms
        let armH = 44 * scale
        let armY = torsoY + 6
        let leftArm  = Path(roundedRect: CGRect(x: cx - 40, y: armY, width: 14, height: armH), cornerRadius: 5)
        let rightArm = Path(roundedRect: CGRect(x: cx + 26, y: armY, width: 14, height: armH), cornerRadius: 5)
        ctx.fill(leftArm,  with: .color(skinColor))
        ctx.fill(rightArm, with: .color(skinColor))

        // Neck
        let neckH: CGFloat = 12
        let neck = Path(roundedRect: CGRect(x: cx - 7, y: torsoY - neckH, width: 14, height: neckH), cornerRadius: 4)
        ctx.fill(neck, with: .color(skinColor))

        // Head
        let headR: CGFloat = 26
        let headY = torsoY - neckH - headR * 2 + 4
        let head = Path(ellipseIn: CGRect(x: cx - headR, y: headY, width: headR * 2, height: headR * 2))
        ctx.fill(head, with: .color(skinColor))

        // Hair overlay (simple top strip)
        if config.hairStyle != .bald {
            let hairColor = Color(hex: config.hairColorHex) ?? .black
            let hairPath = Path(roundedRect: CGRect(x: cx - headR, y: headY, width: headR * 2, height: headR * 0.55), cornerRadius: headR)
            ctx.fill(hairPath, with: .color(hairColor))
        }

        // Aura trail shimmer lines
        for i in 0..<3 {
            let offsetX = CGFloat(i - 1) * 14
            let trailPath = Path { p in
                p.move(to: CGPoint(x: cx + offsetX, y: legTop + legH))
                p.addLine(to: CGPoint(x: cx + offsetX, y: legTop + legH + CGFloat(8 + i * 4) * config.trailIntensity))
            }
            ctx.stroke(trailPath, with: .color(auraColor.opacity(0.4 * config.trailIntensity)), lineWidth: 2)
        }
    }

    private func avatarStatChip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(
                    Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                )
        }
    }

    // MARK: — Section Tab Bar

    private var sectionTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BuilderSection.allCases, id: \.rawValue) { section in
                Button {
                    withAnimation(.spring(response: 0.35)) { activeSection = section }
                } label: {
                    VStack(spacing: 4) {
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(activeSection == section ? .white : .secondary)
                            .tracking(1)

                        Rectangle()
                            .fill(activeSection == section
                                  ? Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                                  : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.cardBackground)
    }

    // MARK: — FACE Section

    private var faceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("FACE PRESET", subtitle: "Your 3D Meshy face model")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(FacePreset.allCases, id: \.rawValue) { preset in
                    facePresetTile(preset)
                }
            }
        }
    }

    private func facePresetTile(_ preset: FacePreset) -> some View {
        let isSelected = config.facePreset == preset
        let auraColor = Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)

        return Button {
            withAnimation(.spring(response: 0.3)) {
                config.facePreset = preset
                config.usePersonalModel = preset.isPersonalModel
                config.meshyAthleteSlotId = preset.isPersonalModel
                    ? "MESHY_elijah_bonds_athlete"
                    : "MESHY_athlete_base_skeleton"
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? auraColor.opacity(0.15) : Color.white.opacity(0.04))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle().stroke(
                                isSelected ? auraColor : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                        )

                    Image(systemName: preset.isPersonalModel ? "person.crop.circle.fill" : "person.circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isSelected ? auraColor : .secondary)
                }

                Text(preset.displayName)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if preset.isPersonalModel {
                    Text("YOUR MODEL")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(auraColor)
                        .tracking(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(auraColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? auraColor.opacity(0.05) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? auraColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: — STYLE Section

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Skin tone
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("SKIN TONE", subtitle: nil)
                HStack(spacing: 10) {
                    ForEach(PlayerSkinTone.allCases, id: \.rawValue) { tone in
                        skinToneSwatch(tone)
                    }
                }
            }

            // Hair style
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("HAIR STYLE", subtitle: nil)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(PlayerHairStyle.allCases, id: \.rawValue) { style in
                        hairStyleChip(style)
                    }
                }
            }

            // Hair color
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("HAIR COLOR", subtitle: nil)
                HStack(spacing: 10) {
                    ForEach(hairColors, id: \.0) { hex, color in
                        colorSwatch(hex: hex, swatch: color, selected: config.hairColorHex == hex) {
                            config.hairColorHex = hex
                        }
                    }
                }
            }
        }
    }

    private func skinToneSwatch(_ tone: PlayerSkinTone) -> some View {
        let isSelected = config.skinTone == tone
        return Button {
            withAnimation(.spring(response: 0.25)) { config.skinTone = tone }
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: tone.hexValue) ?? .brown)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle().stroke(isSelected ? .white : .clear, lineWidth: 2)
                    )
                    .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 4)

                if isSelected {
                    Circle().fill(.white).frame(width: 4, height: 4)
                } else {
                    Circle().fill(.clear).frame(width: 4, height: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func hairStyleChip(_ style: PlayerHairStyle) -> some View {
        let isSelected = config.hairStyle == style
        let auraColor = Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)

        return Button {
            withAnimation(.spring(response: 0.25)) { config.hairStyle = style }
        } label: {
            Text(style.displayName)
                .font(.system(size: 10, weight: isSelected ? .black : .medium, design: .monospaced))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? auraColor.opacity(0.12) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? auraColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: — OUTFIT Section

    private var outfitSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Outfit tier (read-only — PRQ derived)
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("OUTFIT TIER", subtitle: "Unlocked by PRQ — earn higher tiers")
                outfitTierRow
            }

            // Jersey color
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("JERSEY", subtitle: nil)
                colorSwatchRow(swatches: jerseySwatches, selected: config.jerseyColorHex) {
                    config.jerseyColorHex = $0
                }
            }

            // Shorts color
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("SHORTS", subtitle: nil)
                colorSwatchRow(swatches: jerseySwatches, selected: config.shortsColorHex) {
                    config.shortsColorHex = $0
                }
            }

            // Shoe style
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("SHOE STYLE", subtitle: nil)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(PlayerShoeStyle.allCases, id: \.rawValue) { style in
                        hairStyleChip2(label: style.displayName, selected: config.shoeStyle == style) {
                            config.shoeStyle = style
                        }
                    }
                }
            }

            // Shoe color
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("SHOE COLOR", subtitle: nil)
                colorSwatchRow(swatches: shoeSwatches, selected: config.shoeColorHex) {
                    config.shoeColorHex = $0
                }
            }
        }
    }

    private var outfitTierRow: some View {
        HStack(spacing: 10) {
            ForEach([PlayerOutfitTier.standard, .developing, .flight, .elite], id: \.rawValue) { tier in
                let unlocked = config.outfitTier.requiredPRQ <= tier.requiredPRQ
                    ? (scan?.prqScore ?? 0) >= tier.requiredPRQ
                    : false
                let isCurrent = config.outfitTier == tier

                VStack(spacing: 4) {
                    Text(tier.displayName.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(isCurrent ? .white : (unlocked ? .secondary : .tertiary))

                    Text(tier.requiredPRQ == 0 ? "FREE" : "PRQ \(Int(tier.requiredPRQ))"+"+")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(isCurrent ? Color(hex: tier.defaultJerseyHex) ?? Theme.brandCyan : .quaternary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isCurrent ? (Color(hex: tier.defaultJerseyHex) ?? Theme.brandCyan).opacity(0.1) : Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isCurrent ? (Color(hex: tier.defaultJerseyHex) ?? Theme.brandCyan).opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
            }
        }
    }

    // MARK: — GEAR Section

    private var gearSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("ACCESSORIES", subtitle: "Tap to equip or remove")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PlayerAccessory.allCases, id: \.rawValue) { accessory in
                    accessoryTile(accessory)
                }
            }
        }
    }

    private func accessoryTile(_ accessory: PlayerAccessory) -> some View {
        let isEquipped = config.accessories.contains(accessory)
        let auraColor = Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)

        return Button {
            withAnimation(.spring(response: 0.25)) {
                if isEquipped {
                    config.accessories.removeAll(where: { $0 == accessory })
                } else {
                    config.accessories.append(accessory)
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isEquipped ? auraColor.opacity(0.15) : Color.white.opacity(0.04))
                        .frame(width: 36, height: 36)
                    Image(systemName: isEquipped ? "checkmark" : accessoryIcon(accessory))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isEquipped ? auraColor : .secondary)
                }

                Text(accessory.displayName)
                    .font(.system(size: 12, weight: isEquipped ? .black : .medium))
                    .foregroundStyle(isEquipped ? .white : .secondary)

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isEquipped ? auraColor.opacity(0.05) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isEquipped ? auraColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func accessoryIcon(_ a: PlayerAccessory) -> String {
        switch a {
        case .headband:   return "sportscourt"
        case .wristband:  return "bandage"
        case .chain:      return "link"
        case .glasses:    return "eyeglasses"
        case .armband:    return "cross.circle"
        case .kneeSleeve: return "figure.walk"
        }
    }

    // MARK: — Save Button

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.06))
            HStack(spacing: 12) {
                Button {
                    saveAndDeliver()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("SAVE AVATAR")
                    }
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                    )
                    .clipShape(.rect(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, max((UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.safeAreaInsets.bottom ?? 0), 16))
            .background(Theme.deepBlack)
        }
    }

    private func saveAndDeliver() {
        // Deliver appearance JSON to Unreal via bridge
        if let data = try? JSONSerialization.data(withJSONObject: config.toUnrealPayload(), options: [.sortedKeys]) {
            NexusBridge.shared.deliverAvatarAppearanceJSON(data)
        }
        onSave(config)
        dismiss()
    }

    // MARK: — Helpers

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(
                    Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                )
                .tracking(2)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func colorSwatch(hex: String, swatch: Color, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Circle()
                .fill(swatch)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(selected ? .white : .clear, lineWidth: 2))
                .shadow(color: selected ? swatch.opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }

    private func colorSwatchRow(swatches: [(String, Color)], selected: String, onChange: @escaping (String) -> Void) -> some View {
        HStack(spacing: 10) {
            ForEach(swatches, id: \.0) { hex, color in
                colorSwatch(hex: hex, swatch: color, selected: selected == hex) {
                    withAnimation(.spring(response: 0.25)) { onChange(hex) }
                }
            }
        }
    }

    private func hairStyleChip2(label: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        let auraColor = Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
        return Button(action: onTap) {
            Text(label)
                .font(.system(size: 10, weight: selected ? .black : .medium, design: .monospaced))
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? auraColor.opacity(0.12) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selected ? auraColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Color(hex:) convenience

private extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
