import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LiveEventsHubView: View {
    let viewModel: LabViewModel

    @State private var referralSourceUserId: String = ""
    @State private var selectedVoteScore: Int = 8
    @State private var feedbackBanner: LiveEventFeedbackBanner?
    @State private var pendingConfirmation: LiveEventsConfirmation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                walletStrip
                referralCard
                eventsSection
                armorySection
                fundraisingSection
                liveVotingSection
                rewardsLedgerSection
            }
            .padding(.horizontal)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .overlay(alignment: .bottom) {
            if let feedbackBanner {
                HStack(spacing: 10) {
                    Image(systemName: feedbackBanner.isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feedbackBanner.message)
                            .font(.system(size: 12, weight: .bold))
                        if let detail = feedbackBanner.detail {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.black.opacity(0.75))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(feedbackBanner.isError ? Color.orange : Theme.brandCyan)
                .clipShape(.rect(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(item: $pendingConfirmation) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .default(Text(action.confirmButton)) {
                    performConfirmedAction(action)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Command center")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brandBlue)

            Text("Live Events")
                .font(.system(size: 48, weight: .black))
                .italic()
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private var walletStrip: some View {
        HStack(spacing: 10) {
            WalletPill(icon: "creditcard.fill", label: "Credits", value: "\(viewModel.profile.premiumCredits)", color: Theme.brandBlue)
            WalletPill(icon: "diamond.fill", label: "Shards", value: "\(viewModel.profile.evolutionShards)", color: Theme.brandCyan)
            WalletPill(icon: "qrcode", label: "Tickets", value: "\(viewModel.armoryTickets.count)", color: .orange)
        }
    }

    private var referralCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Referral link")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)

            if let event = viewModel.upcomingLiveEvents.first {
                let link = viewModel.referralLink(for: event.id)
                Text(link)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.brandCyan)
                    .lineLimit(1)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Button {
#if canImport(UIKit)
                        UIPasteboard.general.string = link
#endif
                        showFeedback("Referral link copied", detail: "Paste and share this event referral URL.")
                    } label: {
                        Label("Copy link", systemImage: "doc.on.doc")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(Theme.brandBlue)
                            .clipShape(Capsule())
                    }

                    if let shareURL = URL(string: link) {
                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(Theme.foundationGreen)
                                .clipShape(Capsule())
                        }
                    }
                }
            } else {
                Text("No active event link")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            TextField("Referral source user id (optional)", text: $referralSourceUserId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 12, weight: .medium))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                )

            Text("Referrer earns 5% shard bonus on ticket sales")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.brandCyan.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Live events")
            if viewModel.upcomingLiveEvents.isEmpty {
                emptyCard("No upcoming events")
            } else {
                ForEach(viewModel.upcomingLiveEvents) { event in
                    eventCard(event)
                }
            }
        }
    }

    private func eventCard(_ event: LiveEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(event.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(event.kind.rawValue.capitalized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.brandBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.brandBlue.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                eventMeta(icon: "calendar", text: event.startsAt.formatted(date: .abbreviated, time: .shortened))
                eventMeta(icon: "mappin.and.ellipse", text: event.venueName)
            }

            VStack(spacing: 8) {
                ForEach(EventTicketTier.allCases, id: \.self) { tier in
                    if let pricing = viewModel.ticketPricing(for: event.id, tier: tier) {
                        HStack(spacing: 8) {
                            Text(tier.displayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 96, alignment: .leading)

                            Text(priceLabel(pricing: pricing))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                pendingConfirmation = .purchase(eventId: event.id, tier: tier)
                            } label: {
                                Text("Buy")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 44)
                                    .background(Theme.brandBlue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private var armorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Ticket armory")
            if viewModel.armoryTickets.isEmpty {
                emptyCard("No tickets owned yet")
            } else {
                ForEach(viewModel.armoryTickets.prefix(8)) { ticket in
                    HStack(spacing: 10) {
                        Image(systemName: ticket.containsGoldenTicket ? "sparkles.rectangle.stack.fill" : "qrcode.viewfinder")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ticket.containsGoldenTicket ? .yellow : Theme.brandCyan)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(eventTitle(for: ticket.eventId)) • \(ticket.tier.displayName)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(ticket.qrPayload)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if ticket.checkedInAt == nil {
                            Button {
                                pendingConfirmation = .checkIn(ticketId: ticket.id)
                            } label: {
                                Text("Check in")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .frame(minHeight: 44)
                                    .background(Theme.foundationGreen)
                                    .clipShape(Capsule())
                            }
                        } else {
                            Text("Checked")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.foundationGreen)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var fundraisingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Team fundraising")
            if viewModel.activeFundraisingGoals.isEmpty {
                emptyCard("No active goals")
            } else {
                ForEach(viewModel.activeFundraisingGoals) { goal in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(goal.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)

                        progressBar(progress: min(1, Double(goal.currentCredits) / Double(max(1, goal.goalCredits))))

                        HStack {
                            Text("\(goal.currentCredits) / \(goal.goalCredits) credits")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(goal.percentComplete)%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.brandCyan)
                        }

                        HStack(spacing: 8) {
                            donationButton(goalId: goal.id, amount: 250)
                            donationButton(goalId: goal.id, amount: 500)
                            donationButton(goalId: goal.id, amount: 1000)
                        }

                        if !goal.milestoneRewards.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(goal.milestoneRewards, id: \.rewardId) { reward in
                                        let unlocked = goal.unlockedRewardIds.contains(reward.rewardId)
                                        Text("\(reward.thresholdPercent)% • \(reward.rewardType.rawValue)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(unlocked ? .black : .secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(unlocked ? Theme.foundationGreen : Color.white.opacity(0.05))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        let donors = viewModel.topDonors(for: goal.id, limit: 3)
                        if !donors.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Top donors")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                ForEach(Array(donors.enumerated()), id: \.offset) { idx, donor in
                                    HStack {
                                        Text("#\(idx + 1) \(donor.userId)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(donor.credits)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.03))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var liveVotingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Live voting")
            if let event = viewModel.upcomingLiveEvents.first(where: { $0.kind == .dunkShow }) {
                let session = viewModel.eventHub.votingSessions.first(where: { $0.eventId == event.id })
                VStack(alignment: .leading, spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Button {
                            pendingConfirmation = .openVoting(eventId: event.id)
                        } label: {
                            votingActionLabel("Open", color: .green)
                        }
                        Button {
                            pendingConfirmation = .closeVoting(eventId: event.id)
                        } label: {
                            votingActionLabel("Close", color: .orange)
                        }
                    }

                    HStack {
                        Text("SCORE: \(selectedVoteScore)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Stepper("", value: $selectedVoteScore, in: 1...10)
                            .labelsHidden()
                            .accessibilityLabel("Vote score")
                            .accessibilityValue("\(selectedVoteScore)")
                    }

                    Button {
                        let ok = viewModel.submitLiveVote(eventId: event.id, score: selectedVoteScore)
                        showFeedback(
                            ok ? "Vote submitted" : "Vote rejected",
                            detail: ok ? "Your dunk score was recorded." : "Voting requires an open session and a valid ticket.",
                            isError: !ok
                        )
                    } label: {
                        Text("Submit ticket-holder vote")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Theme.brandBlue)
                            .clipShape(.rect(cornerRadius: 10))
                    }

                    HStack {
                        Text("Status: \(session?.isOpen == true ? "Open" : "Closed")")
                        Spacer()
                        Text("Votes: \(session?.votes.count ?? 0)")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    if let outcome = viewModel.eventHub.voteOutcomeByEvent?[event.id] {
                        Text(outcome.summary)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.brandCyan)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                )
            } else {
                emptyCard("No dunk show voting session available")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private var rewardsLedgerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Reward ledger")
            HStack {
                ledgerCell("Referral Shards", value: "\(viewModel.eventHub.referralShardRewardsByUser[viewModel.profile.id] ?? 0)")
                ledgerCell("Vote Shards", value: "\(viewModel.eventHub.participationShardRewardsByUser[viewModel.profile.id] ?? 0)")
            }
            HStack {
                ledgerCell("Golden Tickets", value: "\(viewModel.eventHub.goldenTicketWinners.count)")
                ledgerCell("Patron Mult.", value: "\(viewModel.eventHub.donorShardMultiplierBpsByUser[viewModel.profile.id] ?? 0) bps")
            }
            HStack {
                ledgerCell("Checked-In", value: "\(checkedInCount)")
                Button {
                    pendingConfirmation = .claimReferral
                } label: {
                    Text("Claim referral")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Theme.brandBlue)
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
        )
    }

    private func ledgerCell(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
        )
    }

    private func donationButton(goalId: String, amount: Int) -> some View {
        Button {
            pendingConfirmation = .donate(goalId: goalId, amount: amount)
        } label: {
            Text("+\(amount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(Theme.brandCyan)
                .clipShape(Capsule())
        }
        .accessibilityLabel("Donate \(amount) credits")
        .accessibilityHint("Opens confirmation before submitting donation.")
    }

    private func eventMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
    }

    private func votingActionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule()
                    .fill(
                        LinearGradient(colors: [Theme.brandBlue, Theme.brandCyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.03))
            )
    }

    private var sanitizedReferral: String? {
        let trimmed = referralSourceUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func eventTitle(for eventId: String) -> String {
        viewModel.eventHub.events.first(where: { $0.id == eventId })?.title ?? eventId
    }

    private var checkedInCount: Int {
        viewModel.armoryTickets.filter { $0.checkedInAt != nil }.count
    }

    private func priceLabel(pricing: EventTicketPricing) -> String {
        switch (pricing.priceInCredits, pricing.priceInShards) {
        case let (credits, shards) where credits > 0 && shards > 0:
            return "\(credits) cr + \(shards) sh • +\(pricing.shardBonusValue) sh"
        case let (credits, _) where credits > 0:
            return "\(credits) credits • +\(pricing.shardBonusValue) sh"
        case let (_, shards):
            return "\(shards) shards • +\(pricing.shardBonusValue) sh"
        }
    }

    private func showFeedback(_ message: String, detail: String? = nil, isError: Bool = false) {
        withAnimation(.spring(response: 0.25)) {
            feedbackBanner = LiveEventFeedbackBanner(message: message, detail: detail, isError: isError)
        }
        Task {
            try? await Task.sleep(for: .seconds(2.25))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    feedbackBanner = nil
                }
            }
        }
    }

    private func performConfirmedAction(_ action: LiveEventsConfirmation) {
        switch action {
        case let .purchase(eventId, tier):
            if let ticket = viewModel.purchaseEventTicket(
                eventId: eventId,
                tier: tier,
                referralSourceUserId: sanitizedReferral
            ) {
                showFeedback("Ticket minted: \(ticket.tier.displayName)", detail: "Added to your ticket armory.")
            } else {
                showFeedback("Purchase failed", detail: "Insufficient balance or event pricing unavailable.", isError: true)
            }
        case let .donate(goalId, amount):
            let ok = viewModel.donateToFundraisingGoal(goalId: goalId, creditsAmount: amount)
            showFeedback(
                ok ? "Donated \(amount) credits" : "Donation failed",
                detail: ok ? "Team goal progress has been updated." : "Check credit balance or fundraising goal status.",
                isError: !ok
            )
        case let .checkIn(ticketId):
            let ok = viewModel.checkInTicket(ticketId: ticketId)
            showFeedback(
                ok ? "Ticket checked in (+75 shards)" : "Check-in failed",
                detail: ok ? "You are marked present for this event." : "Check-in is only available during active event windows.",
                isError: !ok
            )
        case .claimReferral:
            let claimed = viewModel.claimReferralShardRewards()
            showFeedback(
                claimed > 0 ? "Claimed \(claimed) shards" : "No referral rewards",
                detail: claimed > 0 ? "Referral rewards added to your shard wallet." : "Share an event referral link to earn rewards.",
                isError: claimed == 0
            )
        case let .openVoting(eventId):
            viewModel.openLiveVoting(eventId: eventId)
            showFeedback("Voting opened", detail: "Ticket holders can now submit scores.")
        case let .closeVoting(eventId):
            let summary = viewModel.closeLiveVoting(eventId: eventId)
            showFeedback("Voting closed", detail: summary ?? "Outcome has been finalized.")
        }
    }
}

private struct LiveEventFeedbackBanner {
    let message: String
    let detail: String?
    let isError: Bool
}

private enum LiveEventsConfirmation: Identifiable {
    case purchase(eventId: String, tier: EventTicketTier)
    case donate(goalId: String, amount: Int)
    case checkIn(ticketId: String)
    case claimReferral
    case openVoting(eventId: String)
    case closeVoting(eventId: String)

    var id: String {
        switch self {
        case let .purchase(eventId, tier): return "purchase-\(eventId)-\(tier.rawValue)"
        case let .donate(goalId, amount): return "donate-\(goalId)-\(amount)"
        case let .checkIn(ticketId): return "checkin-\(ticketId)"
        case .claimReferral: return "claim-referral"
        case let .openVoting(eventId): return "open-voting-\(eventId)"
        case let .closeVoting(eventId): return "close-voting-\(eventId)"
        }
    }

    var title: String {
        switch self {
        case let .purchase(_, tier): return "Confirm \(tier.displayName) ticket purchase?"
        case let .donate(_, amount): return "Donate \(amount) credits?"
        case .checkIn: return "Check in ticket now?"
        case .claimReferral: return "Claim referral shards?"
        case .openVoting: return "Open live voting?"
        case .closeVoting: return "Close live voting?"
        }
    }

    var message: String {
        switch self {
        case .purchase:
            return "This spends wallet funds and mints a ticket."
        case .donate:
            return "Credits donated to team fundraising cannot be reversed."
        case .checkIn:
            return "Check-in confirms attendance for this event window."
        case .claimReferral:
            return "Claiming transfers pending referral shards into your wallet."
        case .openVoting:
            return "Voting session will open for eligible ticket holders."
        case .closeVoting:
            return "Voting will close and rewards/outcomes will be resolved."
        }
    }

    var confirmButton: String {
        switch self {
        case .purchase: return "Buy Ticket"
        case .donate: return "Donate"
        case .checkIn: return "Check In"
        case .claimReferral: return "Claim"
        case .openVoting: return "Open"
        case .closeVoting: return "Close Voting"
        }
    }
}

private struct WalletPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.cardBackground)
        )
    }
}
