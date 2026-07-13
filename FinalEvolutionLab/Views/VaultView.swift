import SwiftUI

struct VaultView: View {
    let viewModel: LabViewModel

    @State private var showEditProfile = false
    @State private var showShardShop = false
    @State private var showCharacterEditor = false
    @State private var showCreatorHub = false
    @State private var showTriumphLobby = false

    var body: some View {
        ScrollView {
            VStack(spacing: FELDesign.Space.lg) {
                headerSection
                lumaHeroSection
                profileCard
                performanceStrip
                creatorHubEntry
                triumphCashTournamentEntry
                healthKitSection
                masterVaultSection
                equipmentSection
                statsGrid
                achievementsSection
            }
            .padding(.horizontal, FELDesign.Space.md)
            .padding(.bottom, FELDesign.Space.xl)
        }
        .scrollIndicators(.hidden)
        .background(FELDesign.Colors.ink)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
        .sheet(isPresented: $showShardShop) {
            ShardShopView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCharacterEditor) {
            SystemScanCharacterEditorView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showCreatorHub) {
            NexusCreatorHubView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showTriumphLobby) {
            TriumphTournamentLobbyView(viewModel: viewModel)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
            FELPreviewLabel(text: FELPremiumCopy.Preview.vaultProfile)

            FELMicroLabel(text: "Athlete Profile", color: FELDesign.Colors.cyan)

            Text("Vault")
                .font(FELDesign.Typography.display)
                .foregroundStyle(FELDesign.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, FELDesign.Space.xs)
    }

    private var lumaHeroSection: some View {
        FELLumaShopViewport(
            height: 176,
            caption: "Venice Showroom",
            subtitle: "Browse rewards in 3D",
            neuralDrive: viewModel.effectiveMetrics.neuralDrive
        )
    }

    private var performanceStrip: some View {
        HStack(spacing: FELDesign.Space.sm) {
            VaultMetricPill(
                label: FELEconomyLabels.performanceScore,
                value: "\(Int(viewModel.competitivePRQScore))",
                icon: "chart.line.uptrend.xyaxis",
                color: FELDesign.Colors.cyan
            )
            VaultMetricPill(
                label: FELEconomyLabels.shards,
                value: "\(viewModel.profile.evolutionShards)",
                icon: "diamond.fill",
                color: FELDesign.Colors.cyan
            )
            VaultMetricPill(
                label: FELEconomyLabels.focusEnergyShort,
                value: "\(Int(viewModel.effectiveMetrics.neuralDrive))",
                icon: "brain.head.profile.fill",
                color: FELDesign.Colors.cyan
            )
        }
    }

    private var creatorHubEntry: some View {
        Button {
            showCreatorHub = true
        } label: {
            VaultEntryRow(
                icon: "video.badge.plus",
                title: "Mocap Creator Hub",
                subtitle: "Mint custom cards · Track shard royalties",
                badge: "MINTING"
            )
        }
        .buttonStyle(.plain)
    }

    private var triumphCashTournamentEntry: some View {
        Button {
            showTriumphLobby = true
        } label: {
            VaultEntryRow(
                icon: "dollarsign.circle.fill",
                title: "Competitive Cash Arena",
                subtitle: "Manage cash balance · View tournament ledger",
                badge: "CASH"
            )
        }
        .buttonStyle(.plain)
    }

    private var profileCard: some View {
        VStack(spacing: FELDesign.Space.md) {
            ZStack {
                Circle()
                    .fill(FELDesign.Colors.surfaceRaised)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                    )

                Image(systemName: viewModel.profile.avatarSystemName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(FELDesign.Colors.cyan)
            }

            VStack(spacing: FELDesign.Space.xxs) {
                Text(viewModel.profile.displayName)
                    .font(FELDesign.Typography.heading)
                    .foregroundStyle(FELDesign.Colors.textPrimary)

                Text(viewModel.profile.athleteTag)
                    .font(FELDesign.Typography.stat)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }

            Text("Joined \(viewModel.profile.joinDate, format: .dateTime.month(.wide).year())")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)

            VStack(spacing: FELDesign.Space.sm) {
                HStack(spacing: FELDesign.Space.sm) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Edit Profile")
                            .font(FELDesign.Typography.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FELDesign.Space.sm)
                            .background(FELDesign.Colors.surfaceRaised)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                            )
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                    }

                    Button {
                        showShardShop = true
                    } label: {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 10))
                            Text("Shop")
                        }
                        .font(FELDesign.Typography.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FELDesign.Space.sm)
                        .background(FELDesign.Colors.cyan)
                        .clipShape(Capsule())
                        .foregroundStyle(FELDesign.Colors.ink)
                    }
                }

                Button {
                    showCharacterEditor = true
                } label: {
                    HStack(spacing: FELDesign.Space.xs) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                        Text("Character Customization")
                    }
                    .font(FELDesign.Typography.label)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FELDesign.Space.sm)
                    .background(FELDesign.Colors.surfaceRaised)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                    )
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .felCard(padding: FELDesign.Space.lg)
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                FELMicroLabel(text: "Health Data")

                Spacer()

                if !viewModel.healthKit.isAuthorized {
                    Button {
                        Task { await viewModel.connectHealthKit() }
                    } label: {
                        Text("CONNECT")
                            .font(FELDesign.Typography.micro)
                            .tracking(FELDesign.Typography.microTracking)
                            .padding(.horizontal, FELDesign.Space.sm)
                            .padding(.vertical, 6)
                            .background(FELDesign.Colors.cyan)
                            .foregroundStyle(FELDesign.Colors.ink)
                            .clipShape(Capsule())
                    }
                }
            }

            if viewModel.healthKit.isAuthorized {
                HStack(spacing: FELDesign.Space.sm) {
                    HealthMetric(label: "HR", value: "\(Int(viewModel.healthKit.heartRate))", unit: "bpm", icon: "heart.fill", color: FELDesign.Colors.cyan)
                    HealthMetric(label: "CALORIES", value: "\(Int(viewModel.healthKit.activeCalories))", unit: "kcal", icon: "flame.fill", color: FELDesign.Colors.cyan)
                    HealthMetric(label: "RHR", value: "\(Int(viewModel.healthKit.restingHeartRate))", unit: "bpm", icon: "waveform.path.ecg", color: FELDesign.Colors.cyan)
                }
            } else {
                HStack(spacing: FELDesign.Space.sm) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(FELDesign.Colors.textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health")
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        Text("Connect to sync heart rate and activity data")
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .felCard()
            }
        }
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Lifetime Stats")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: FELDesign.Space.sm), GridItem(.flexible(), spacing: FELDesign.Space.sm)], spacing: FELDesign.Space.sm) {
                StatCell(label: "Total Workouts", value: "\(viewModel.profile.totalWorkouts)", icon: "figure.run")
                StatCell(label: FELEconomyLabels.shards, value: "\(viewModel.profile.evolutionShards)", icon: "diamond.fill")
                StatCell(label: "Day Streak", value: "\(viewModel.profile.streakDays)", icon: "flame.fill")
                StatCell(label: "Sessions Today", value: "\(viewModel.todaysSessions.count)", icon: "clock.fill")
            }
        }
    }

    private var masterVaultSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Master Vault")

            ForEach(VaultResources.videos, id: \.title) { resource in
                Link(destination: resource.url) {
                    VaultResourceRow(
                        icon: resource.icon,
                        title: resource.title,
                        subtitle: resource.description,
                        promoCode: nil
                    )
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Equipment & Tools")

            ForEach(VaultResources.equipment, id: \.title) { item in
                Link(destination: item.url) {
                    VaultResourceRow(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.description,
                        promoCode: item.promoCode
                    )
                }
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Achievements")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: FELDesign.Space.sm), GridItem(.flexible(), spacing: FELDesign.Space.sm), GridItem(.flexible(), spacing: FELDesign.Space.sm)], spacing: FELDesign.Space.sm) {
                AchievementBadge(name: "First Rep", icon: "1.circle.fill", unlocked: viewModel.profile.totalWorkouts >= 1)
                AchievementBadge(name: "Week Warrior", icon: "7.circle.fill", unlocked: viewModel.profile.streakDays >= 7)
                AchievementBadge(name: "Shard Collector", icon: "diamond.fill", unlocked: viewModel.profile.evolutionShards >= 100)
                AchievementBadge(name: "Focus Master", icon: "brain.head.profile.fill", unlocked: viewModel.profile.metrics.neuralDrive >= 50)
                AchievementBadge(name: "Performance Ready", icon: "airplane.departure", unlocked: viewModel.profile.metrics.prqScore >= 50)
                AchievementBadge(name: "Top Performer", icon: "crown.fill", unlocked: viewModel.profile.metrics.prqScore >= 90, accent: FELDesign.Colors.purple)
            }
        }
    }
}

/// Full-width navigation entry card (Creator Hub, Cash Arena).
private struct VaultEntryRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String

    var body: some View {
        HStack(spacing: FELDesign.Space.md) {
            ZStack {
                Circle()
                    .fill(FELDesign.Colors.surfaceRaised)
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FELDesign.Colors.cyan)
            }
            VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                HStack(spacing: FELDesign.Space.xs) {
                    Text(title.uppercased())
                        .font(FELDesign.Typography.micro)
                        .tracking(FELDesign.Typography.microTracking)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                    FELPreviewLabel(text: badge)
                }
                Text(subtitle)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FELDesign.Colors.textTertiary)
        }
        .felCard()
    }
}

/// External resource link row (videos, equipment) with optional promo code chip.
private struct VaultResourceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let promoCode: String?

    var body: some View {
        HStack(spacing: FELDesign.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                    .fill(FELDesign.Colors.surfaceRaised)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FELDesign.Colors.cyan)
            }

            VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                Text(title)
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let code = promoCode {
                VStack(spacing: 2) {
                    FELMicroLabel(text: "Code")
                    Text(code)
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
                .padding(.horizontal, FELDesign.Space.xs)
                .padding(.vertical, 6)
                .background(FELDesign.Colors.surfaceRaised)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.sm))
            } else {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }
        }
        .felCard(padding: FELDesign.Space.sm)
    }
}

struct VaultMetricPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: FELDesign.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(FELDesign.Typography.stat)
                .foregroundStyle(FELDesign.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label.uppercased())
                .font(FELDesign.Typography.micro)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FELDesign.Space.sm)
        .padding(.horizontal, FELDesign.Space.xs)
        .background(FELDesign.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
        )
    }
}

struct HealthMetric: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: FELDesign.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(FELDesign.Typography.stat)
                .foregroundStyle(FELDesign.Colors.textPrimary)

            Text(unit)
                .font(FELDesign.Typography.statSmall)
                .foregroundStyle(FELDesign.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FELDesign.Space.md)
        .background(FELDesign.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
        )
    }
}

struct StatCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FELDesign.Colors.cyan)

            Text(value)
                .font(FELDesign.Typography.statLarge)
                .foregroundStyle(FELDesign.Colors.textPrimary)

            FELMicroLabel(text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .felCard()
    }
}

struct AchievementBadge: View {
    let name: String
    let icon: String
    let unlocked: Bool
    var accent: Color = FELDesign.Colors.cyan

    var body: some View {
        VStack(spacing: FELDesign.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(unlocked ? accent : FELDesign.Colors.textTertiary.opacity(0.5))

            Text(name.uppercased())
                .font(FELDesign.Typography.micro)
                .foregroundStyle(unlocked ? FELDesign.Colors.textPrimary : FELDesign.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FELDesign.Space.md)
        .background(FELDesign.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                .stroke(unlocked ? accent.opacity(0.35) : FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
        )
    }
}

private enum AthleteIdentityValidation {
    static let reservedTagsLowercased: Set<String> = [
        "admin", "administrator", "fel", "official", "support", "system", "moderator", "staff", "finalevolution", "root",
    ]

    static func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayNameError(_ raw: String) -> String? {
        let n = trimmed(raw)
        if n.isEmpty { return "Display name cannot be empty." }
        if n.count > 40 { return "Use at most 40 characters." }
        return nil
    }

    /// Client-side guardrails; public arena still needs server-side reserved-tag enforcement (GAME-48).
    static func athleteTagError(_ raw: String) -> String? {
        let t = trimmed(raw)
        if t.isEmpty { return "Athlete tag cannot be empty." }
        if t.count < 3 || t.count > 20 { return "Tag must be 3–20 characters." }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if !t.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return "Use letters, numbers, and underscores only."
        }
        if reservedTagsLowercased.contains(t.lowercased()) {
            return "That tag is reserved."
        }
        return nil
    }
}

struct EditProfileView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var tag: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $name)
                    TextField("Athlete Tag", text: $tag)
                }
                .listRowBackground(FELDesign.Colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(FELDesign.Colors.ink)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let message = AthleteIdentityValidation.displayNameError(name) {
                            FelToastCenter.shared.show(message, isError: true)
                            return
                        }
                        if let message = AthleteIdentityValidation.athleteTagError(tag) {
                            FelToastCenter.shared.show(message, isError: true)
                            return
                        }
                        viewModel.profile.displayName = AthleteIdentityValidation.trimmed(name)
                        viewModel.profile.athleteTag = AthleteIdentityValidation.trimmed(tag)
                        SaveSystem.saveProfile(viewModel.profile)
                        dismiss()
                    }
                    .foregroundStyle(FELDesign.Colors.cyan)
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = viewModel.profile.displayName
                tag = viewModel.profile.athleteTag
            }
        }
    }
}
