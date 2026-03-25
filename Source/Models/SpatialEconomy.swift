// MARK: - Spatial Sports Economy: Dual-Currency (Credits = hard, Shards = soft)
// Credits: purchased with USD; used for Shards, critiques, event tickets, Lures. Creators cash out.

import Foundation

nonisolated enum CreditTransaction: String, Codable, Sendable {
    case purchase
    case buyShards
    case critique
    case eventTicket
    case lurePlacement
    case creatorEarn
    case cashOut
}

nonisolated struct CreditLedgerEntry: Sendable {
    let amount: Int
    let transaction: CreditTransaction
    let at: Date
    let refId: String?

    init(amount: Int, transaction: CreditTransaction, at: Date = Date(), refId: String? = nil) {
        self.amount = amount
        self.transaction = transaction
        self.at = at
        self.refId = refId
    }
}

/// Hard currency balance and audit trail. In production, balance is server-authoritative.
nonisolated struct CreditsBalance: Sendable {
    var balance: Int
    var ledger: [CreditLedgerEntry]

    init(balance: Int = 0, ledger: [CreditLedgerEntry] = []) {
        self.balance = balance
        self.ledger = ledger
    }

    mutating func add(_ amount: Int, transaction: CreditTransaction, refId: String? = nil) {
        guard amount > 0 else { return }
        balance += amount
        ledger.append(CreditLedgerEntry(amount: amount, transaction: transaction, refId: refId))
    }

    mutating func spend(_ amount: Int, transaction: CreditTransaction, refId: String? = nil) -> Bool {
        guard amount > 0, balance >= amount else { return false }
        balance -= amount
        ledger.append(CreditLedgerEntry(amount: -amount, transaction: transaction, refId: refId))
        return true
    }
}

/// Creator earnings (Credits) from critiques, tickets, etc.; cash-out is backend.
nonisolated struct CreatorEarnings: Codable, Sendable {
    var totalEarned: Int
    var availableToCashOut: Int
    var totalCashedOut: Int
    var lastCashOutAt: Date?

    init(totalEarned: Int = 0, availableToCashOut: Int = 0, totalCashedOut: Int = 0, lastCashOutAt: Date? = nil) {
        self.totalEarned = totalEarned
        self.availableToCashOut = availableToCashOut
        self.totalCashedOut = totalCashedOut
        self.lastCashOutAt = lastCashOutAt
    }
}
