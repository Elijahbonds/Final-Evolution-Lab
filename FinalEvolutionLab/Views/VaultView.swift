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
            VStack(spacing: 24) {
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
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
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
        VStack(alignment: .leading, spacing: 4) {
            FELPreviewLabel(text: FELPremiumCopy.Preview.vaultProfile)

            Text("ATHLETE PROFILE")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)

            Text("Vault")
                .font(.system(size: 52, weight: .black))
                .italic()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
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
        HStack(spacing: 10) {
            VaultMetricPill(
                label: FELEconomyLabels.performanceScore,
                value: "\(Int(viewModel.competitivePRQScore))",
                icon: "chart.line.uptrend.xyaxis",
                color: Theme.neonGreen
            )
            VaultMetricPill(
                label: FELEconomyLabels.shards,
                value: "\(viewModel.profile.evolutionShards)",
                icon: "diamond.fill",
                color: Theme.brandCyan
            )
            VaultMetricPill(
                label: FELEconomyLabels.focusEnergyShort,
                value: "\(Int(viewModel.effectiveMetrics.neuralDrive))",
                icon: "brain.head.profile.fill",
                color: Theme.brandBlue
            )
        }
    }

    private var creatorHubEntry: some View {
        Button {
            showCreatorHub = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("MOCAP CREATOR HUB")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                        FELPreviewLabel(text: "MINTING")
                    }
                    Text("Mint custom cards · Track shard royalties")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.45), Theme.elitePurple.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var triumphCashTournamentEntry: some View {
        Button {
            showTriumphLobby = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("COMPETITIVE CASH ARENA")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.white)
                        FELPreviewLabel(text: "CASH")
                    }
                    Text("Manage cash balance · View tournament ledger")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.45), Theme.elitePurple.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var profileCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.brandBlue.opacity(0.2), Theme.cardBackground],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: viewModel.profile.avatarSystemName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)
            }

            VStack(spacing: 4) {
                Text(viewModel.profile.displayName)
                    .font(.system(.title3, weight: .black))
                    .foregroundStyle(.white)

                Text(viewModel.profile.athleteTag)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue.opacity(0.7))
            }

            Text("Joined \(viewModel.profile.joinDate, format: .dateTime.month(.wide).year())")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("EDIT PROFILE")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }

                    Button {
                        showShardShop = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 10))
                            Text("Shop")
                        }
                        .font(.system(.caption, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.brandCyan.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(Theme.brandCyan)
                    }
                }

                Button {
                    showCharacterEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                        Text("CHARACTER CUSTOMIZATION")
                    }
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.brandBlue.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(Theme.brandBlue)
                    .overlay(
                        Capsule()
                            .stroke(Theme.brandBlue.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandBlue.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HEALTH DATA")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()

                if !viewModel.healthKit.isAuthorized {
                    Button {
                        Task { await viewModel.connectHealthKit() }
                    } label: {
                        Text("CONNECT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.brandBlue.opacity(0.15))
                            .foregroundStyle(Theme.brandBlue)
                            .clipShape(Capsule())
                    }
                }
            }

            if viewModel.healthKit.isAuthorized {
                HStack(spacing: 12) {
                    HealthMetric(label: "HR", value: "\(Int(viewModel.healthKit.heartRate))", unit: "bpm", icon: "heart.fill", color: .red)
                    HealthMetric(label: "CALORIES", value: "\(Int(viewModel.healthKit.activeCalories))", unit: "kcal", icon: "flame.fill", color: .orange)
                    HealthMetric(label: "RHR", value: "\(Int(viewModel.healthKit.restingHeartRate))", unit: "bpm", icon: "waveform.path.ecg", color: .pink)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title2)
                        .foregroundStyle(.red.opacity(0.5))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Connect to sync heart rate and activity data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardBackground)
                )
            }
        }
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LIFETIME STATS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StatCell(label: "Total Workouts", value: "\(viewModel.profile.totalWorkouts)", icon: "figure.run")
                StatCell(label: FELEconomyLabels.shards, value: "\(viewModel.profile.evolutionShards)", icon: "diamond.fill")
                StatCell(label: "Day Streak", value: "\(viewModel.profile.streakDays)", icon: "flame.fill")
                StatCell(label: "Sessions Today", value: "\(viewModel.todaysSessions.count)", icon: "clock.fill")
            }
        }
    }

    private var masterVaultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MASTER VAULT")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15))
                    .tracking(2)

                Spacer()
            }

            ForEach(VaultResources.videos, id: \.title) { resource in
                Link(destination: resource.url) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.95, green: 0.49, blue: 0.15).opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: resource.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(resource.title.uppercased())
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(resource.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15).opacity(0.6))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.95, green: 0.49, blue: 0.15).opacity(0.08), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EQUIPMENT & TOOLS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            ForEach(VaultResources.equipment, id: \.title) { item in
                Link(destination: item.url) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.brandBlue.opacity(0.1))
                                .frame(width: 44, height: 44)

                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.brandBlue)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title.uppercased())
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(item.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if let code = item.promoCode {
                            VStack(spacing: 2) {
                                Text("CODE")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Text(code)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.95, green: 0.49, blue: 0.15).opacity(0.08))
                            .clipShape(.rect(cornerRadius: 8))
                        } else {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.brandBlue.opacity(0.6))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.cardBorder, lineWidth: 0.5)
                            )
                    )
                }
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACHIEVEMENTS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                AchievementBadge(name: "First Rep", icon: "1.circle.fill", unlocked: viewModel.profile.totalWorkouts >= 1)
                AchievementBadge(name: "Week Warrior", icon: "7.circle.fill", unlocked: viewModel.profile.streakDays >= 7)
                AchievementBadge(name: "Shard Collector", icon: "diamond.fill", unlocked: viewModel.profile.evolutionShards >= 100)
                AchievementBadge(name: "Focus Master", icon: "brain.head.profile.fill", unlocked: viewModel.profile.metrics.neuralDrive >= 50)
                AchievementBadge(name: "Performance Ready", icon: "airplane.departure", unlocked: viewModel.profile.metrics.prqScore >= 50)
                AchievementBadge(name: "Top Performer", icon: "crown.fill", unlocked: viewModel.profile.metrics.prqScore >= 90)
            }
        }
    }
}

struct VaultMetricPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.12), lineWidth: 0.5)
                )
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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(.white)

            Text(unit)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct StatCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.brandBlue)

            Text(value)
                .font(.system(.title2, design: .monospaced, weight: .black))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
    }
}

struct AchievementBadge: View {
    let name: String
    let icon: String
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(unlocked ? Theme.brandBlue : Color.white.opacity(0.1))

            Text(name.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(unlocked ? Color.white : Color.white.opacity(0.2))
                .multilineTextAlignment(.center)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(unlocked ? Theme.brandBlue.opacity(0.06) : Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(unlocked ? Theme.brandBlue.opacity(0.15) : .clear, lineWidth: 0.5)
                )
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
            }
            .scrollContentBackground(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
