import Combine
import Foundation
import SwiftUI
import FirebaseDataConnect
import SocialDataConnect

/// Form-based color presets for custom minted creator cards.
enum CreatorCardColorPreset: String, Codable, CaseIterable, Sendable {
    case yellow
    case orange
    case purple
    case red
    case green
    case blue
    case cyan
    
    public var color: Color {
        switch self {
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .cyan: return .init(red: 0, green: 0.95, blue: 0.9)
        }
    }
}

/// Codable persistence record for custom minted creator cards.
struct MintedCreatorCardRecord: Codable, Sendable, Identifiable {
    let id: String
    let creatorName: String
    let title: String
    let description: String
    let costShards: Int
    let iconName: String
    let accentColorPreset: CreatorCardColorPreset
    let prqBoost: Double
    let verticalBoost: Double
    let neuralDriveBoost: Double
    let animationKey: String
    
    func toCreatorCard() -> CreatorCard {
        CreatorCard(
            id: id,
            creatorName: creatorName,
            title: title,
            description: description,
            costShards: costShards,
            iconName: iconName,
            accentColor: accentColorPreset.color,
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5.0,
                prqScore: prqBoost,
                readinessScore: 5.0,
                verticalPotential: verticalBoost,
                neuralDrive: neuralDriveBoost,
                currentOutfit: "custom_minted"
            ),
            movementSignature: MovementSignature(
                style: .standard,
                jumpApex: 1.0 + (verticalBoost / 50.0),
                hangTimeFactor: 1.0 + (verticalBoost / 40.0),
                firstStepBurst: 1.0 + (prqBoost / 100.0),
                limbEmission: 0.6,
                trailColor: accentColorPreset.color
            )
        )
    }
}

/// Engine that handles the creation and minting of custom Creator Cards from captured animations,
/// synchronizes them with the SQL backend via Data Connect, and registers them in the local catalog.
@Observable
@MainActor
class NexusCreatorCardMinter {
    static let shared = NexusCreatorCardMinter()
    
    private let mintedCardsKey = "finalEvolution_mintedCreatorCards_v1"
    
    // UI Form State
    var selectedAnimation: NexusAnimationAsset? = nil
    var cardTitle: String = ""
    var cardDescription: String = ""
    var shardCost: Int = 250
    var selectedColorPreset: CreatorCardColorPreset = .cyan
    
    // Stats Boost sliders
    var prqBoost: Double = 10.0
    var verticalBoost: Double = 12.0
    var neuralDriveBoost: Double = 8.0
    
    // Status indicators
    var isMinting: Bool = false
    var mintingSuccess: Bool = false
    var errorMessage: String? = nil
    
    private init() {
        loadAndApplyMintedCards()
    }
    
    /// Pre-populates form with default inputs for a swift user experience.
    func resetForm(with animation: NexusAnimationAsset?) {
        self.selectedAnimation = animation
        self.cardTitle = animation.map { "\($0.header.movementType) Masterpiece" } ?? "My Custom Card"
        self.cardDescription = "Custom minted data card featuring high-performance capture. PRQ +\(animation?.header.movementType ?? "Athletic") mechanics."
        self.shardCost = 300
        self.selectedColorPreset = .cyan
        self.prqBoost = 10.0
        self.verticalBoost = 15.0
        self.neuralDriveBoost = 10.0
        self.mintingSuccess = false
        self.errorMessage = nil
    }
    
    /// Entrypoint to mint a new creator card from selected form inputs.
    /// Programmatically appends it to the local catalog and syncs to backend SQL.
    func mintCreatorCard() async {
        guard !cardTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a card title."
            return
        }
        
        let profile = SaveSystem.loadProfile()
        guard profile.evolutionShards >= shardCost else {
            errorMessage = "Insufficient Evolution Shards (Required: \(shardCost), Balance: \(profile.evolutionShards))."
            return
        }
        
        isMinting = true
        errorMessage = nil
        mintingSuccess = false
        
        // Formulate unique IDs
        let timestamp = Int(Date().timeIntervalSince1970)
        let cardId = "custom_mint_\(timestamp)"
        let animationKey = selectedAnimation?.header.movementType.replacingOccurrences(of: " ", with: "_").lowercased() ?? "custom_mocap"
        
        let record = MintedCreatorCardRecord(
            id: cardId,
            creatorName: profile.displayName.isEmpty ? "Me" : profile.displayName,
            title: cardTitle,
            description: cardDescription,
            costShards: shardCost,
            iconName: "sparkles",
            accentColorPreset: selectedColorPreset,
            prqBoost: prqBoost,
            verticalBoost: verticalBoost,
            neuralDriveBoost: neuralDriveBoost,
            animationKey: animationKey
        )
        
        do {
            // 1. Sync to Cloud SQL via Firebase Data Connect if configured
            if FirebaseBootstrap.isConfigured {
                TrainingLabSocialBridge.shared.configureConnectorIfNeeded()
                
                // First ensure SQL user exists
                _ = try await TrainingLabSocialBridge.shared.ensureSqlUserRegistration(displayName: profile.displayName)
                
                // 1.1 Insert CreatorCard catalog item in Backend SQL
                _ = try await DataConnect.socialConnector.createCreatorCardCatalogItemMutation.execute(
                    catalogCardId: cardId,
                    displayName: cardTitle
                ) { v in
                    v.rarityTier = "custom"
                }
                
                // 1.2 Spend shards locally and on backend
                try await TrainingLabSocialBridge.shared.recordShardLedgerDelta(
                    deltaShards: -shardCost,
                    reason: "creator_card_purchase",
                    referenceId: cardId
                )
                
                // 1.3 Claim ownership of our newly minted creator card
                try await TrainingLabSocialBridge.shared.claimCreatorCardOwnership(catalogCardId: cardId)
            }
            
            // 2. Instantiate and Register CreatorCard in the local static catalog
            let creatorCard = record.toCreatorCard()
            CreatorCard.catalog.append(creatorCard)
            
            // 3. Update local user profile economy shards and inventory
            var updatedProfile = profile
            updatedProfile.evolutionShards -= shardCost
            updatedProfile.ownedCardIds.append(cardId)
            SaveSystem.saveProfile(updatedProfile)
            
            // 4. Persist the custom card metadata locally for next launch
            var savedRecords = loadMintedCardsFromDisk()
            savedRecords.append(record)
            saveMintedCardsToDisk(savedRecords)
            
            // 5. Update UI State
            mintingSuccess = true
            isMinting = false
            
        } catch {
            isMinting = false
            errorMessage = "Minting failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Disk Persistence
    
    func loadMintedCardsFromDisk() -> [MintedCreatorCardRecord] {
        guard let data = UserDefaults.standard.data(forKey: mintedCardsKey),
              let records = try? JSONDecoder().decode([MintedCreatorCardRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private func saveMintedCardsToDisk(_ records: [MintedCreatorCardRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: mintedCardsKey)
        }
    }
    
    func loadAndApplyMintedCards() {
        let records = loadMintedCardsFromDisk()
        for record in records {
            let card = record.toCreatorCard()
            if !CreatorCard.catalog.contains(where: { $0.id == card.id }) {
                CreatorCard.catalog.append(card)
            }
        }
    }
}
