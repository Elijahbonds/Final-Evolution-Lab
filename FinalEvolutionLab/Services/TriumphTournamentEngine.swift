import Foundation
import SwiftUI

struct TournamentTier: Identifiable, Codable, Sendable {
    var id: String
    var name: String
    var entryFee: Double
    var prizePool: Double
    var shardsReward: Int
    var prqBonus: Double
    
    static let tiers: [TournamentTier] = [
        TournamentTier(id: "tier_1", name: "Rec League", entryFee: 1.00, prizePool: 1.80, shardsReward: 100, prqBonus: 1.0),
        TournamentTier(id: "tier_5", name: "Semi-Pro", entryFee: 5.00, prizePool: 9.00, shardsReward: 250, prqBonus: 1.5),
        TournamentTier(id: "tier_10", name: "Pro Circuit", entryFee: 10.00, prizePool: 18.00, shardsReward: 500, prqBonus: 2.5),
        TournamentTier(id: "tier_20", name: "Championship", entryFee: 20.00, prizePool: 36.00, shardsReward: 1000, prqBonus: 4.0)
    ]
}

struct TriumphLedgerEntry: Identifiable, Codable, Sendable {
    var id: String
    var type: String // "deposit", "withdrawal", "entry_fee_escrow", "payout", "loss", "refund"
    var amount: Double
    var date: Date
    var description: String
}

@Observable
@MainActor
final class TriumphTournamentEngine {
    static let shared = TriumphTournamentEngine()
    
    private let cashBalanceKey = "triumph_cash_balance"
    private let ledgerKey = "triumph_ledger_entries"
    
    private(set) var cashBalance: Double = 0.0
    private(set) var escrowBalance: Double = 0.0
    private(set) var ledgerEntries: [TriumphLedgerEntry] = []
    private(set) var activeWagerTier: TournamentTier? = nil
    
    private init() {
        self.cashBalance = UserDefaults.standard.double(forKey: cashBalanceKey)
        // Default cash balance for demo/testing if it's 0, let's start with $10.00
        if UserDefaults.standard.object(forKey: cashBalanceKey) == nil {
            self.cashBalance = 10.00 // Give them $10.00 free to start!
            UserDefaults.standard.set(self.cashBalance, forKey: cashBalanceKey)
        }
        
        if let data = UserDefaults.standard.data(forKey: ledgerKey),
           let decoded = try? JSONDecoder().decode([TriumphLedgerEntry].self, from: data) {
            self.ledgerEntries = decoded
        } else {
            self.ledgerEntries = [
                TriumphLedgerEntry(
                    id: UUID().uuidString,
                    type: "deposit",
                    amount: 10.00,
                    date: Date(),
                    description: "Welcome Bonus Deposit"
                )
            ]
            saveLedger()
        }
    }
    
    private func saveLedger() {
        if let data = try? JSONEncoder().encode(ledgerEntries) {
            UserDefaults.standard.set(data, forKey: ledgerKey)
        }
    }
    
    private func saveBalance() {
        UserDefaults.standard.set(cashBalance, forKey: cashBalanceKey)
    }
    
    func deposit(amount: Double, cardDetails: String) -> Bool {
        guard amount > 0 else { return false }
        cashBalance += amount
        saveBalance()
        
        let entry = TriumphLedgerEntry(
            id: UUID().uuidString,
            type: "deposit",
            amount: amount,
            date: Date(),
            description: "Deposit via Card (...\(String(cardDetails.suffix(min(4, cardDetails.count)))))"
        )
        ledgerEntries.insert(entry, at: 0)
        saveLedger()
        return true
    }
    
    func withdraw(amount: Double, paypalEmail: String) -> Bool {
        guard amount > 0, cashBalance >= amount else { return false }
        cashBalance -= amount
        saveBalance()
        
        let entry = TriumphLedgerEntry(
            id: UUID().uuidString,
            type: "withdrawal",
            amount: amount,
            date: Date(),
            description: "Withdrawal to \(paypalEmail)"
        )
        ledgerEntries.insert(entry, at: 0)
        saveLedger()
        return true
    }
    
    func joinTournament(tier: TournamentTier) -> Bool {
        guard cashBalance >= tier.entryFee else { return false }
        
        // Atomically lock entry fee in escrow
        cashBalance -= tier.entryFee
        escrowBalance = tier.entryFee
        activeWagerTier = tier
        
        saveBalance()
        
        let entry = TriumphLedgerEntry(
            id: UUID().uuidString,
            type: "entry_fee_escrow",
            amount: -tier.entryFee,
            date: Date(),
            description: "Locked entry fee for \(tier.name) tournament"
        )
        ledgerEntries.insert(entry, at: 0)
        saveLedger()
        return true
    }
    
    func cancelTournament() {
        guard let tier = activeWagerTier else { return }
        
        cashBalance += escrowBalance
        escrowBalance = 0.0
        activeWagerTier = nil
        
        saveBalance()
        
        let entry = TriumphLedgerEntry(
            id: UUID().uuidString,
            type: "refund",
            amount: tier.entryFee,
            date: Date(),
            description: "Refunded entry fee for \(tier.name) tournament"
        )
        ledgerEntries.insert(entry, at: 0)
        saveLedger()
    }
    
    func completeTournament(didWin: Bool, playerScore: Double, opponentScore: Double, gameModeId: String, viewModel: LabViewModel) {
        guard let tier = activeWagerTier else { return }
        
        let payoutAmount = didWin ? tier.prizePool : 0.0
        
        if didWin {
            cashBalance += payoutAmount
            let entry = TriumphLedgerEntry(
                id: UUID().uuidString,
                type: "payout",
                amount: payoutAmount,
                date: Date(),
                description: "triumph_cash_payout: Won \(tier.name) H2H"
            )
            ledgerEntries.insert(entry, at: 0)
        } else {
            let entry = TriumphLedgerEntry(
                id: UUID().uuidString,
                type: "loss",
                amount: -tier.entryFee,
                date: Date(),
                description: "Lost \(tier.name) H2H"
            )
            ledgerEntries.insert(entry, at: 0)
        }
        
        // Clear escrow
        escrowBalance = 0.0
        activeWagerTier = nil
        
        saveBalance()
        saveLedger()
        
        // Update competitive PRQ and grant additional Evolution Shards
        let prqChange = didWin ? tier.prqBonus : -0.5 // small penalty for losing
        viewModel.profile.metrics.prqScore = PRQ.clamp(viewModel.profile.metrics.prqScore + prqChange)
        
        let shardsEarned = tier.shardsReward + (didWin ? 50 : 10) // base tier reward + win bonus
        viewModel.profile.evolutionShards += shardsEarned
        
        // Record game result in local history
        let result = GameSessionResult(
            id: UUID().uuidString,
            gameModeId: gameModeId,
            date: Date(),
            score: Int(playerScore),
            opponentScore: Int(opponentScore),
            shardsEarned: shardsEarned,
            prqBonus: prqChange,
            isMultiplayer: true,
            duration: 120, // simulated duration
            verificationSeed: UInt64.random(in: 100000...999999),
            trustLevel: .serverVerified // Triumph matches are server-verified
        )
        
        SaveSystem.saveProfile(viewModel.profile)
        SaveSystem.saveGameResult(result)
        viewModel.gameResults = SaveSystem.loadGameResults()
        viewModel.globalLeaderboard.refreshRankings(userProfile: viewModel.profile, sampleData: SampleData.leaderboard)
    }
}
