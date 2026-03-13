import SwiftUI

struct LiveEventsHubView: View {
    let viewModel: LabViewModel

    @State private var referralSourceUserId: String = ""
    @State private var selectedVoteScore: Int = 8
    @State private var toastMessage: String?

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
            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.brandCyan)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("COMMAND CENTER")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)

            Text("Live Events")
                .font(.system(size: 48, weight: .black))
                .italic()
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private var walletStrip: some View {
        HStack(spacing: 10) {
            WalletPill(icon: "creditcard.fill", label: "CREDITS", value: "\(viewModel.profile.premiumCredits)", color: Theme.brandBlue)
            WalletPill(icon: "diamond.fill", label: "SHARDS", value: "\(viewModel.profile.evolutionShards)", color: Theme.brandCyan)
            WalletPill(icon: "qrcode", label: "TICKETS", value: "\(viewModel.armoryTickets.count)", color: .orange)
        }
    }

    private var referralCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REFERRAL LINK")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            if let event = viewModel.upcomingLiveEvents.first {
                Text(viewModel.referralLink(for: event.id))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .lineLimit(1)
            } else {
                Text("No active event link")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            TextField("Referral source user id (optional)", text: $referralSourceUserId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                )

            Text("Referrer earns 5% shard bonus on ticket sales")
                .font(.system(size: 9, design: .monospaced))
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
            sectionLabel("LIVE EVENTS")
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
                    Text(event.title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(event.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(event.kind.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
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
                            Text(tier.displayName.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 96, alignment: .leading)

                            Text(priceLabel(pricing: pricing))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                if let ticket = viewModel.purchaseEventTicket(
                                    eventId: event.id,
                                    tier: tier,
                                    referralSourceUserId: sanitizedReferral
                                ) {
                                    showToast("Ticket minted: \(ticket.tier.displayName)")
                                } else {
                                    showToast("Purchase failed")
                                }
                            } label: {
                                Text("BUY")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
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
            sectionLabel("TICKET ARMORY")
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
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text(ticket.qrPayload)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
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
            sectionLabel("TEAM FUNDRAISING")
            if viewModel.activeFundraisingGoals.isEmpty {
                emptyCard("No active goals")
            } else {
                ForEach(viewModel.activeFundraisingGoals) { goal in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(goal.title.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)

                        progressBar(progress: min(1, Double(goal.currentCredits) / Double(max(1, goal.goalCredits))))

                        HStack {
                            Text("\(goal.currentCredits) / \(goal.goalCredits) credits")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(goal.percentComplete)%")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
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
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
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
                                Text("TOP DONORS")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                ForEach(Array(donors.enumerated()), id: \.offset) { idx, donor in
                                    HStack {
                                        Text("#\(idx + 1) \(donor.userId)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(donor.credits)")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
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
            sectionLabel("LIVE VOTING")
            if let event = viewModel.upcomingLiveEvents.first(where: { $0.kind == .dunkShow }) {
                let session = viewModel.eventHub.votingSessions.first(where: { $0.eventId == event.id })
                VStack(alignment: .leading, spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Button {
                            viewModel.openLiveVoting(eventId: event.id)
                            showToast("Voting opened")
                        } label: {
                            votingActionLabel("OPEN", color: .green)
                        }
                        Button {
                            viewModel.closeLiveVoting(eventId: event.id)
                            showToast("Voting closed")
                        } label: {
                            votingActionLabel("CLOSE", color: .orange)
                        }
                    }

                    HStack {
                        Text("SCORE: \(selectedVoteScore)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Stepper("", value: $selectedVoteScore, in: 1...10)
                            .labelsHidden()
                    }

                    Button {
                        let ok = viewModel.submitLiveVote(eventId: event.id, score: selectedVoteScore)
                        showToast(ok ? "Vote submitted" : "Vote rejected")
                    } label: {
                        Text("SUBMIT TICKET-HOLDER VOTE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.brandBlue)
                            .clipShape(.rect(cornerRadius: 10))
                    }

                    HStack {
                        Text("Status: \(session?.isOpen == true ? "OPEN" : "CLOSED")")
                        Spacer()
                        Text("Votes: \(session?.votes.count ?? 0)")
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
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
            sectionLabel("REWARD LEDGER")
            HStack {
                ledgerCell("Referral Shards", value: "\(viewModel.eventHub.referralShardRewardsByUser[viewModel.profile.id] ?? 0)")
                ledgerCell("Vote Shards", value: "\(viewModel.eventHub.participationShardRewardsByUser[viewModel.profile.id] ?? 0)")
            }
            HStack {
                ledgerCell("Golden Tickets", value: "\(viewModel.eventHub.goldenTicketWinners.count)")
                ledgerCell("Patron Mult.", value: "\(viewModel.eventHub.donorShardMultiplierBpsByUser[viewModel.profile.id] ?? 0) bps")
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
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
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
            let ok = viewModel.donateToFundraisingGoal(goalId: goalId, creditsAmount: amount)
            showToast(ok ? "Donated \(amount) credits" : "Donation failed")
        } label: {
            Text("+\(amount)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.brandCyan)
                .clipShape(Capsule())
        }
    }

    private func eventMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 8, design: .monospaced))
        }
        .foregroundStyle(.secondary)
    }

    private func votingActionLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.tertiary)
            .tracking(2)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
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

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.25)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    toastMessage = nil
                }
            }
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
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
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
