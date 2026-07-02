import SwiftUI

/// A beautiful detail sheet for creator cards triggered by deep links.
/// Prompts the user to equip the card (if owned) or purchase it (if not owned).
struct NexusDeepLinkCardDetailView: View {
    let card: CreatorCard
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false
    @State private var showInsufficientShards = false
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.3).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Card Icon and Glow
                    ZStack {
                        Circle()
                            .fill(card.accentColor.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)
                        
                        Circle()
                            .stroke(card.accentColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: card.iconName)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(card.accentColor)
                    }
                    
                    // Creator and Title
                    VStack(spacing: 8) {
                        Text(card.creatorName.uppercased())
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(card.accentColor)
                            .tracking(2)
                        
                        Text(card.title)
                            .font(.system(.title, weight: .black))
                            .italic()
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    
                    // Description
                    Text(card.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    NexusCreatorIPShowcaseSection(card: card)

                    if card.usesCatalogPlaceholderPreview {
                        FELPreviewLabel(text: FELPremiumCopy.Preview.sceneKitStub)
                    }
                    
                    // Boosts Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PERFORMANCE BOOSTS")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        
                        HStack(spacing: 16) {
                            boostBadge(label: "PRQ", value: "+\(Int(card.metricsBoost.prqScore))", color: card.accentColor)
                            boostBadge(label: "VERT", value: "+\(Int(card.metricsBoost.verticalPotential))\"", color: .orange)
                            boostBadge(label: "DRIVE", value: "+\(Int(card.metricsBoost.neuralDrive))", color: Theme.brandBlue)
                        }
                    }
                    .padding()
                    .background(Theme.slateCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Actions
                    let isOwned = viewModel.profile.ownsCard(card.id)
                    let isActive = viewModel.profile.activeCreatorCard?.cardId == card.id
                    
                    VStack(spacing: 12) {
                        if let masterclassURLString = card.masterclassURL, let masterclassURL = URL(string: masterclassURLString) {
                            Button {
                                NexusDeepLinkRouter.shared.activeSafariURL = IdentifiableURL(url: masterclassURL)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.tv.fill")
                                    Text("ACCESS MASTERCLASS")
                                }
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(card.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        if let productURLString = card.productURL, let productURL = URL(string: productURLString) {
                            Button {
                                NexusDeepLinkRouter.shared.activeSafariURL = IdentifiableURL(url: productURL)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "bag.fill")
                                    Text("VIEW PRODUCT")
                                }
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.brandBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        if isActive {
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("CURRENTLY ACTIVE")
                                }
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(true)
                        } else if isOwned {
                            Button {
                                viewModel.applyCreatorCard(card)
                                FelToastCenter.shared.show("Equipped \(card.title)!")
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("EQUIP CARD")
                                }
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.brandCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        } else {
                            let canAfford = viewModel.profile.evolutionShards >= card.costShards
                            Button {
                                if canAfford {
                                    showConfirm = true
                                } else {
                                    showInsufficientShards = true
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "diamond.fill")
                                    Text("UNLOCK FOR \(card.costShards) SHARDS")
                                }
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canAfford ? Theme.brandCyan : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        Button("CLOSE") {
                            dismiss()
                        }
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Creator Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Unlock Creator Card", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Unlock") {
                    isProcessing = true
                    viewModel.applyCreatorCard(card)
                    FelToastCenter.shared.show("Unlocked and equipped \(card.title)!")
                    dismiss()
                }
            } message: {
                Text("Spend \(card.costShards) shards to unlock and equip \(card.title)?")
            }
            .alert("Insufficient Shards", isPresented: $showInsufficientShards) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You need \(card.costShards) shards to unlock this card, but you only have \(viewModel.profile.evolutionShards) shards. Complete workouts and arena matches to earn more.")
            }
        }
    }
    
    private func boostBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .monospaced, weight: .black))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Premium glass panel for creator IP links — masterclass, product, IMDb, Spotify, gallery, bio.
struct NexusCreatorIPShowcaseSection: View {
    let card: CreatorCard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CREATOR IP")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            Text(card.resolvedMiniBio)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(card.resolvedLinks.indices, id: \.self) { index in
                    let link = card.resolvedLinks[index]
                    if let url = URL(string: link.url) {
                        ipLinkButton(title: link.label, icon: linkIcon(for: link.type), url: url, tint: card.accentColor)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(card.accentColor.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    private func linkIcon(for type: CreatorLink.LinkType) -> String {
        switch type {
        case .masterclass: return "play.tv.fill"
        case .imdb: return "film.stack"
        case .product: return "bag.fill"
        case .website: return "globe"
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "link"
        case .spotify: return "music.note"
        case .gallery: return "photo.on.rectangle.angled"
        case .tiktok: return "play.circle.fill"
        case .twitter: return "at"
        case .podcast: return "mic.fill"
        }
    }

    private func ipLinkButton(title: String, icon: String, url: URL, tint: Color) -> some View {
        Button {
            NexusDeepLinkRouter.shared.activeSafariURL = IdentifiableURL(url: url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title.uppercased())
                    .font(.system(.caption, design: .monospaced, weight: .black))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(tint.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
