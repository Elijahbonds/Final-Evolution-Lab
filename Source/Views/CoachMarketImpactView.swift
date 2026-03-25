import SwiftUI
import Observation

/// Coach-facing analytics — local ledger from `CreatorPayoutLedger.json` (70% coach shard accrual vs 30% platform).
struct CoachMarketImpactView: View {
    @Bindable private var subsystem = UFELCreatorRevenueSubsystem.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("MARKET IMPACT")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Theme.brandCyan.opacity(0.9))

                statCard(
                    title: "Athletes standing your card",
                    value: "\(subsystem.marketImpact.athletesStandingYourCard)",
                    caption: "Unique equip events (local profile id)"
                )

                statCard(
                    title: "Sovereign skins sold",
                    value: "\(subsystem.marketImpact.skinsSold)",
                    caption: "Exclusive gear ledger rows"
                )

                statCard(
                    title: "Coach revenue (70% shard accrual)",
                    value: "\(subsystem.marketImpact.totalRevenueCoachShards)",
                    caption: "Sum of coachShards70 · Platform retains 30% per row"
                )

                Text("Ledger: Documents/FEL/CreatorPayoutLedger.json — NSFileProtectionComplete")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Theme.deepBlack)
        .navigationTitle("Coach Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            subsystem.reloadFromDisk()
        }
        .onReceive(NotificationCenter.default.publisher(for: .felCreatorRevenueTransactionPending)) { _ in
            subsystem.reloadFromDisk()
        }
    }

    private func statCard(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(caption)
                .font(.system(size: 11, design: .default))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.brandCyan.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
