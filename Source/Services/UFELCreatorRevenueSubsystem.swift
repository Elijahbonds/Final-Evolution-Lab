import Foundation
import Observation

extension Notification.Name {
    /// Creator economy — ledger row appended (`UFELCreatorRevenueSubsystem`).
    static let felCreatorRevenueTransactionPending = Notification.Name("FelCreatorRevenueTransactionPending")
}

/// Gold Master Creator Revenue Loop: 70% Coach / 30% Platform on each qualifying shard transaction, persisted to `CreatorPayoutLedger.json`.
@Observable
@MainActor
final class UFELCreatorRevenueSubsystem {
    static let shared = UFELCreatorRevenueSubsystem()

    private let ledgerFileName = "CreatorPayoutLedger.json"
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private(set) var entries: [CreatorPayoutLedgerEntry] = []

    /// Aggregated coach-facing metrics (local shell; sync server in production).
    private(set) var marketImpact: CoachMarketImpact = CoachMarketImpact()

    private init() {
        reloadFromDisk()
        recomputeMarketImpact()
    }

    func reloadFromDisk() {
        guard let url = try? ledgerURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode(CreatorPayoutLedger.self, from: data) else {
            entries = []
            return
        }
        entries = decoded.entries.sorted { $0.occurredAt > $1.occurredAt }
    }

    /// 70/30 split on **gross** shard spend for marketplace items (Sovereign Gear + Creator Card SKU purchases).
    func recordMarketplacePurchase(item: ShopItem, grossShards: Int) {
        guard grossShards > 0 else { return }
        let split = Self.coachPlatformSplit(grossShards: grossShards)
        let entry = CreatorPayoutLedgerEntry(
            id: UUID().uuidString,
            kind: .marketplacePurchase,
            itemId: item.id,
            itemName: item.name,
            felMerchantID: item.creatorMerchantID,
            grossShards: grossShards,
            coachShards70: split.coach,
            platformShards30: split.platform,
            occurredAt: Date(),
            athleteAnonId: nil,
            stoodCardId: nil
        )
        appendAndPersist(entry)
        NotificationCenter.default.post(
            name: .felCreatorRevenueTransactionPending,
            object: nil,
            userInfo: [
                "itemId": item.id,
                "grossShards": grossShards,
                "coachShards70": split.coach,
                "platformShards30": split.platform,
                "felMerchantID": item.creatorMerchantID as Any
            ]
        )
    }

    /// Creator Card SKU purchase (first unlock) — 70/30 on shard spend.
    func recordCreatorCardUnlock(card: CreatorCard, grossShards: Int) {
        guard grossShards > 0 else { return }
        let split = Self.coachPlatformSplit(grossShards: grossShards)
        let entry = CreatorPayoutLedgerEntry(
            id: UUID().uuidString,
            kind: .creatorCardPurchase,
            itemId: card.id,
            itemName: card.title,
            felMerchantID: card.felMerchantID,
            grossShards: grossShards,
            coachShards70: split.coach,
            platformShards30: split.platform,
            occurredAt: Date(),
            athleteAnonId: nil,
            stoodCardId: nil
        )
        appendAndPersist(entry)
        NotificationCenter.default.post(
            name: .felCreatorRevenueTransactionPending,
            object: nil,
            userInfo: [
                "kind": "creatorCardPurchase",
                "itemId": card.id,
                "grossShards": grossShards,
                "coachShards70": split.coach,
                "platformShards30": split.platform
            ]
        )
    }

    /// Creator Card equipped as a “Stand” — attributes athlete to coach funnel (local anonymized id).
    func recordCardStand(athleteAnonId: String, cardId: String, coachMerchantID: String?) {
        let entry = CreatorPayoutLedgerEntry(
            id: UUID().uuidString,
            kind: .cardStand,
            itemId: cardId,
            itemName: "Stand:\(cardId)",
            felMerchantID: coachMerchantID,
            grossShards: 0,
            coachShards70: 0,
            platformShards30: 0,
            occurredAt: Date(),
            athleteAnonId: athleteAnonId,
            stoodCardId: cardId
        )
        appendAndPersist(entry)
    }

    private func appendAndPersist(_ entry: CreatorPayoutLedgerEntry) {
        entries.insert(entry, at: 0)
        recomputeMarketImpact()
        persist()
    }

    private func persist() {
        guard let url = try? ledgerURL() else { return }
        let ledger = CreatorPayoutLedger(schemaVersion: 1, entries: entries)
        guard let data = try? encoder.encode(ledger) else { return }
        do {
            try data.write(to: url, options: [.atomic])
            try FELBiometricFileProtection.applyCompleteProtection(to: url)
        } catch {
            try? data.write(to: url, options: [.atomic])
        }
    }

    private func ledgerURL() throws -> URL {
        let fel = try FELDocumentsFolder.urlCreatingIfNeeded()
        return fel.appendingPathComponent(ledgerFileName)
    }

    private func recomputeMarketImpact() {
        var skins = 0
        var revenueCoach = 0
        var standKeys = Set<String>()
        for e in entries {
            switch e.kind {
            case .marketplacePurchase:
                if e.itemId.hasPrefix("gear_") || e.itemId.contains("jersey") || e.itemId.contains("shoes") {
                    skins += 1
                }
                revenueCoach += e.coachShards70
            case .cardStand:
                if let aid = e.athleteAnonId, let cid = e.stoodCardId {
                    standKeys.insert("\(aid)|\(cid)")
                }
            case .creatorCardPurchase:
                revenueCoach += e.coachShards70
            }
        }
        marketImpact = CoachMarketImpact(
            athletesStandingYourCard: standKeys.count,
            skinsSold: skins,
            totalRevenueCoachShards: revenueCoach
        )
    }

    /// Integer 70/30 split: `coach + platform == gross` for all `gross > 0` (remainder assigned to platform via subtraction).
    nonisolated static func coachPlatformSplit(grossShards: Int) -> (coach: Int, platform: Int) {
        guard grossShards > 0 else { return (0, 0) }
        let coach = (grossShards * 7_000) / 10_000
        let platform = grossShards - coach
        return (coach, platform)
    }
}

// MARK: - Ledger model

nonisolated struct CreatorPayoutLedger: Codable, Sendable {
    var schemaVersion: Int
    var entries: [CreatorPayoutLedgerEntry]
}

nonisolated struct CreatorPayoutLedgerEntry: Codable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case marketplacePurchase
        case creatorCardPurchase
        case cardStand
    }

    var id: String
    var kind: Kind
    var itemId: String
    var itemName: String
    var felMerchantID: String?
    var grossShards: Int
    var coachShards70: Int
    var platformShards30: Int
    var occurredAt: Date
    var athleteAnonId: String?
    var stoodCardId: String?
}

nonisolated struct CoachMarketImpact: Sendable {
    var athletesStandingYourCard: Int = 0
    var skinsSold: Int = 0
    var totalRevenueCoachShards: Int = 0
}
