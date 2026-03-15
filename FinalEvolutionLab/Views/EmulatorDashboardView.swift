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
                integrationSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.deepBlack)
        .sheet(isPresented: $showAcademy) {
            VerticalVelocityAcademyView()
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
                    subtitle: "Big Brain × Coursebox",
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
                    title: "Vault",
                    subtitle: "Profile, shards, trade",
                    icon: "person.crop.circle.fill",
                    color: Color.orange
                ) { selectedTab = .vault }
            }
        }
    }

    private var integrationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INTEGRATIONS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
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
