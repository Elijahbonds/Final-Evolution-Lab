import SwiftUI

struct SocialView: View {
    let viewModel: LabViewModel

    @State private var appeared = false
    @State private var selectedTier: PRQTier?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                tierProgressCard
                yourRankCard
                tierFilterChips
                leaderboardList
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .onAppear {
            withAnimation(.spring(response: 0.5)) { appeared = true }
            viewModel.globalLeaderboard.refreshRankings(
                userProfile: viewModel.profile,
                sampleData: SampleData.leaderboard
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GLOBAL RANKINGS")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)

            Text("Arena")
                .font(.system(size: 52, weight: .black))
                .italic()
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private var tierProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                PRQTierBadge(tier: viewModel.userPRQTier, prq: viewModel.competitivePRQScore)

                Spacer()

                if viewModel.globalLeaderboard.userGlobalRank > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("#\(viewModel.globalLeaderboard.userGlobalRank)")
                            .font(.system(.title3, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                        Text("GLOBAL RANK")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .tracking(1)
                    }
                }
            }

            let progress = viewModel.globalLeaderboard.tierProgress(for: viewModel.competitivePRQScore)
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tierColor(viewModel.userPRQTier), tierColor(viewModel.userPRQTier).opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)

                if progress < 1.0, let nextTierName = nextTierName(for: viewModel.userPRQTier) {
                    Text("Next: \(nextTierName)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(tierColor(viewModel.userPRQTier).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var yourRankCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.brandBlue.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: viewModel.profile.avatarSystemName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.profile.displayName.uppercased())
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(.white)

                Text(viewModel.profile.athleteTag)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f", viewModel.competitivePRQScore))
                    .font(.system(.title3, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)

                Text("RANKED PRQ")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.brandBlue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.brandBlue.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var tierFilterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                TierChip(label: "ALL", isSelected: selectedTier == nil) {
                    selectedTier = nil
                }

                ForEach(PRQTier.allCases, id: \.rawValue) { tier in
                    TierChip(
                        label: tier.rawValue,
                        icon: tier.displayIcon,
                        color: tierColor(tier),
                        isSelected: selectedTier == tier
                    ) {
                        selectedTier = selectedTier == tier ? nil : tier
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var filteredRankings: [LeaderboardEntry] {
        guard let tier = selectedTier else {
            return viewModel.globalLeaderboard.globalRankings
        }
        return viewModel.globalLeaderboard.globalRankings.filter {
            PRQTier.fromPRQ($0.prqScore) == tier
        }
    }

    private var leaderboardList: some View {
        VStack(spacing: 8) {
            ForEach(Array(filteredRankings.enumerated()), id: \.element.id) { index, entry in
                GlobalLeaderboardRow(entry: entry)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.spring(response: 0.4).delay(Double(index) * 0.05), value: appeared)
            }
        }
    }

    private func tierColor(_ tier: PRQTier) -> Color {
        switch tier {
        case .diamond: Theme.brandCyan
        case .platinum: Color(white: 0.85)
        case .gold: .yellow
        case .silver: Color(white: 0.7)
        case .bronze: Color(red: 0.8, green: 0.5, blue: 0.2)
        case .unranked: .gray
        }
    }

    private func nextTierName(for tier: PRQTier) -> String? {
        let all = PRQTier.allCases
        guard let index = all.firstIndex(of: tier), index > 0 else { return nil }
        return all[index - 1].rawValue
    }
}

struct TierChip: View {
    let label: String
    var icon: String? = nil
    var color: Color = Theme.brandBlue
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(isSelected ? .black : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct GlobalLeaderboardRow: View {
    let entry: LeaderboardEntry

    private var tier: PRQTier {
        PRQTier.fromPRQ(entry.prqScore)
    }

    private var rankColor: Color {
        switch entry.rank {
        case 1: .yellow
        case 2: Color(white: 0.75)
        case 3: Color(red: 0.8, green: 0.5, blue: 0.2)
        default: .secondary
        }
    }

    private var tierColor: Color {
        switch tier {
        case .diamond: Theme.brandCyan
        case .platinum: Color(white: 0.85)
        case .gold: .yellow
        case .silver: Color(white: 0.7)
        case .bronze: Color(red: 0.8, green: 0.5, blue: 0.2)
        case .unranked: .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(rankColor)
                .frame(width: 28, alignment: .center)

            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: entry.avatarSystemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(rankColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.athleteName)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Text(entry.athleteTag)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Image(systemName: tier.displayIcon)
                        .font(.system(size: 8))
                        .foregroundStyle(tierColor)

                    Text(tier.rawValue)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(tierColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", entry.prqScore))
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)

                HStack(spacing: 2) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.brandCyan)
                    Text("\(entry.evolutionShards)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(entry.rank <= 3 ? rankColor.opacity(0.04) : Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(entry.rank <= 3 ? rankColor.opacity(0.12) : Theme.cardBorder, lineWidth: 0.5)
                )
        )
    }
}
