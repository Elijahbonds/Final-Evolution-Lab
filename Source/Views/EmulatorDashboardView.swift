import SwiftUI

// MARK: - Emulator-style game library (ROM selection)
// Each module is presented as a "cartridge" — controller-first, cross-platform shell.

struct EmulatorDashboardView: View {
    @Binding var selectedTab: AppTab
    var viewModel: LabViewModel
    @State private var showAcademy: Bool = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                controllerStatusSection
                gameLibrarySection
                arenaModesSection
                venueShortcutsSection
                integrationSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.deepBlack)
        .sheet(isPresented: $showAcademy) {
            VerticalVelocityAcademyView(
                viewModel: viewModel,
                onOpenTraining: {
                    showAcademy = false
                    selectedTab = .training
                },
                initialModuleId: viewModel.preselectedAcademyModuleId
            )
        }
        .onChange(of: viewModel.preselectedAcademyModuleId) { _, newId in
            if let id = newId, !id.isEmpty {
                showAcademy = true
            }
        }
        .onChange(of: showAcademy) { _, open in
            if !open {
                viewModel.preselectedAcademyModuleId = nil
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GAME LIBRARY")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Theme.brandBlue)
            Text("Insert game")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var controllerStatusSection: some View {
        if ControllerDiscoveryService.shared.hasPhysicalController {
            HStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.brandCyan)
                Text(ControllerDiscoveryService.shared.controllerName ?? "Controller")
                    .font(.system(size: 13, weight: .semibold))
                Text("connected — overlay hidden")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.brandCyan.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.brandCyan.opacity(0.3), lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(ControllerDiscoveryService.shared.controllerName ?? "Controller") connected; on-screen controller hidden")
        }
    }

    private var gameLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODULES")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: 16) {
                romCard(
                    title: "Arena",
                    subtitle: "Venues & head-to-head",
                    icon: "sportscourt.fill",
                    color: Theme.brandCyan
                ) { selectedTab = .arena }
                romCard(
                    title: "Lab",
                    subtitle: "Court & dunk contest",
                    icon: "brain.head.profile.fill",
                    color: Theme.flightBlue
                ) { selectedTab = .lab }
                romCard(
                    title: "Brain Brawl",
                    subtitle: "Curriculum quiz vs AI",
                    icon: "brain.head.profile",
                    color: Color(red: 0.6, green: 0.35, blue: 0.9)
                ) {
                    viewModel.preselectedArenaModeId = .brainBrawl
                    selectedTab = .arena
                }
                romCard(
                    title: "Training",
                    subtitle: "Blueprints & workouts",
                    icon: "figure.highintensity.intervaltraining",
                    color: Theme.elitePurple
                ) { selectedTab = .training }
                romCard(
                    title: "Academy",
                    subtitle: "Vertical Velocity 10 modules",
                    icon: "book.closed.fill",
                    color: Color(red: 0.2, green: 0.7, blue: 0.5)
                ) { showAcademy = true }
                romCard(
                    title: "Status",
                    subtitle: "Dashboard & metrics",
                    icon: "gauge.with.dots.needle.67percent",
                    color: Theme.brandBlue
                ) { selectedTab = .dashboard }
                romCard(
                    title: "Film Vault",
                    subtitle: "Biomech film + overlays",
                    icon: "film.stack.fill",
                    color: Theme.brandBlue
                ) { selectedTab = .filmVault }
                romCard(
                    title: "Evolution Stream",
                    subtitle: "Live & VOD coaching",
                    icon: "dot.radiowaves.left.and.right",
                    color: Theme.elitePurple
                ) { selectedTab = .evolutionStream }
                romCard(
                    title: "Vault",
                    subtitle: "Profile, shards, trade",
                    icon: "person.crop.circle.fill",
                    color: Color.orange
                ) { selectedTab = .vault }
            }
        }
    }

    /// One-tap launch for every registered Arena mode (12) → Arena tab + preselected mode.
    private var arenaModesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ARENA MODES")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Text("All sports hook into the same Get Ready → Play → Result flow.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(GameModeRegistry.all) { mode in
                    modeLaunchCard(mode: mode)
                }
            }
        }
    }

    private func modeLaunchCard(mode: GameMode) -> some View {
        Button {
            VenueManager.openMode(mode.id, viewModel: viewModel, selectedTab: $selectedTab)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(mode.accentColor)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(mode.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(mode.accentColor.opacity(0.9))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(mode.accentColor.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.name). \(mode.subtitle)")
        .accessibilityHint("Opens this mode in Arena")
    }

    private var venueShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VENUES")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text("Jump to Arena with PRQ export synced for Unreal `readiness_snapshot.json`.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                venueJumpButton(title: "Venice Beach", icon: "sun.max.fill") {
                    VenueManager.openVenue(.veniceBeach, viewModel: viewModel, selectedTab: $selectedTab)
                }
                venueJumpButton(title: "Dojo", icon: "figure.martial.arts") {
                    VenueManager.openVenue(.dojo, viewModel: viewModel, selectedTab: $selectedTab)
                }
                venueJumpButton(title: "Dunk → Lab", icon: "figure.highintensity.intervaltraining") {
                    VenueManager.openDunkContestLab(viewModel: viewModel, selectedTab: $selectedTab)
                }
            }
        }
    }

    private func venueJumpButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.brandCyan)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.brandCyan.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var integrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INTEGRATIONS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            UnrealRuntimePlaceholderView()
            HStack(spacing: 12) {
                integrationPill(icon: "heart.fill", label: "Fitness")
                integrationPill(icon: "brain.head.profile", label: "Education")
                integrationPill(icon: "diamond.fill", label: "Economy")
            }
        }
    }

    private func romCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(color.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    private func integrationPill(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isStaticText)
    }
}
