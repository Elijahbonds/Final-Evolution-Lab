import SwiftUI

/// Post-scan screen to customize appearance and outfit before entering the lab.
/// Persisted via onSave; caller applies updated config to SystemScanResult / UserProfile.
struct AvatarCustomizeView: View {
    let initialConfig: AvatarSkinConfig
    let onSave: (AvatarSkinConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var config: AvatarSkinConfig

    init(initialConfig: AvatarSkinConfig, onSave: @escaping (AvatarSkinConfig) -> Void) {
        self.initialConfig = initialConfig
        self.onSave = onSave
        _config = State(initialValue: initialConfig)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewSection
                    skinToneSection
                    proportionsSection
                    outfitSection
                    auraSection
                }
                .padding()
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Customize Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(config)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var previewSection: some View {
        VStack(spacing: 10) {
            Text("PREVIEW")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            ZStack {
                Circle()
                    .fill(
                        Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                            .opacity(0.2)
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "figure.stand")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                    )
                    .scaleEffect(x: config.weightScale, y: config.heightScale)
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB).opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
    }

    private var skinToneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SKIN TONE")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                ForEach([AvatarSkinTone.green, .blue, .cyan, .elitePurple, .orange], id: \.self) { tone in
                    Button {
                        config.skinTone = tone
                        applyToneToAura(tone)
                    } label: {
                        Text(toneLabel(tone))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(config.skinTone == tone ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(toneColor(tone).opacity(config.skinTone == tone ? 1 : 0.25))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var proportionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("BODY PROPORTIONS")
            sliderRow(label: "Height", value: $config.heightScale, range: 0.85...1.2, format: "%.0f%%", multiplier: 100)
            sliderRow(label: "Build", value: $config.weightScale, range: 0.85...1.2, format: "%.0f%%", multiplier: 100)
            sliderRow(label: "Reach", value: $config.limbLength, range: 0.9...1.15, format: "%.0f%%", multiplier: 100)
        }
    }

    private var outfitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("OUTFIT")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach([AvatarOutfitStyle.standard, .developing, .flight, .elite], id: \.self) { style in
                    Button {
                        config.outfitStyle = style
                        applyOutfitToAura(style)
                    } label: {
                        Text(style.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(config.outfitStyle == style ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.brandCyan.opacity(config.outfitStyle == style ? 0.9 : 0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var auraSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("AURA INTENSITY")
            sliderRow(label: "Trail", value: $config.trailIntensity, range: 0...1, format: "%.0f%%", multiplier: 100)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(2)
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, multiplier: Double) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Slider(value: value, in: range)
                .tint(Theme.brandCyan)
            Text(String(format: format, value.wrappedValue * multiplier))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.cardBackground)
        )
    }

    private func toneLabel(_ tone: AvatarSkinTone) -> String {
        switch tone {
        case .green: return "Green"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .elitePurple: return "Elite"
        case .orange: return "Orange"
        }
    }

    private func toneColor(_ tone: AvatarSkinTone) -> Color {
        switch tone {
        case .green: return Color(red: 0.2, green: 1.0, blue: 0.4)
        case .blue: return Color(red: 0, green: 0.83, blue: 1.0)
        case .cyan: return Color(red: 0, green: 0.95, blue: 0.9)
        case .elitePurple: return Color(red: 0.6, green: 0.2, blue: 1.0)
        case .orange: return Color(red: 1.0, green: 0.5, blue: 0.2)
        }
    }

    private func applyToneToAura(_ tone: AvatarSkinTone) {
        let (r, g, b) = auraRGB(for: tone)
        config.auraColorR = r
        config.auraColorG = g
        config.auraColorB = b
    }

    private func applyOutfitToAura(_ style: AvatarOutfitStyle) {
        switch style {
        case .standard: config.auraColorR = 0.2; config.auraColorG = 1.0; config.auraColorB = 0.4
        case .developing: config.auraColorR = 0; config.auraColorG = 0.83; config.auraColorB = 1.0
        case .flight: config.auraColorR = 0; config.auraColorG = 0.95; config.auraColorB = 0.9
        case .elite: config.auraColorR = 0.6; config.auraColorG = 0.2; config.auraColorB = 1.0
        }
    }

    private func auraRGB(for tone: AvatarSkinTone) -> (Double, Double, Double) {
        switch tone {
        case .green: return (0.2, 1.0, 0.4)
        case .blue: return (0, 0.83, 1.0)
        case .cyan: return (0, 0.95, 0.9)
        case .elitePurple: return (0.6, 0.2, 1.0)
        case .orange: return (1.0, 0.5, 0.2)
        }
    }
}
