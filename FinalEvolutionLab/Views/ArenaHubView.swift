import SwiftUI

struct ArenaHubView: View {
    var viewModel: LabViewModel
    @State private var segment: ArenaSegment = .modes
    @AppStorage(Config.emulatorShellDefaultsKey) private var useEmulatorShell = true

    private var showsArcadeLibrary: Bool {
        Config.useEmulatorShell && useEmulatorShell
    }

    var body: some View {
        VStack(spacing: 0) {
            arenaSegmentPicker
                .padding(.horizontal, FELDesign.Space.md)
                .padding(.vertical, FELDesign.Space.sm)

            Group {
                switch segment {
                case .feed:
                    CommunityFeedView()
                case .modes:
                    if showsArcadeLibrary {
                        ArcadeLibraryView(viewModel: viewModel)
                    } else {
                        GameModeSelectionView(viewModel: viewModel)
                    }
                case .create:
                    NexusGameGeneratorView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(FELDesign.Colors.ink)
    }

    private var arenaSegmentPicker: some View {
        HStack(spacing: FELDesign.Space.xxs) {
            ForEach(ArenaSegment.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        segment = tab
                    }
                } label: {
                    HStack(spacing: FELDesign.Space.xxs) {
                        Image(systemName: tab.icon)
                            .font(FELDesign.Typography.micro)
                        Text(tab.title)
                            .font(FELDesign.Typography.caption)
                    }
                    .foregroundStyle(segment == tab ? FELDesign.Colors.ink : FELDesign.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FELDesign.Space.xs)
                    .background(
                        Capsule()
                            .fill(segment == tab ? FELDesign.Colors.cyan : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ArenaSegment_\(tab.rawValue)")
            }
        }
        .padding(FELDesign.Space.xxs)
        .background(
            Capsule()
                .fill(FELDesign.Colors.surface)
                .overlay(Capsule().strokeBorder(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))
        )
        .accessibilityIdentifier("ArenaSegmentedControl")
    }
}

private enum ArenaSegment: String, CaseIterable, Identifiable {
    case feed
    case modes
    case create

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: return "Community"
        case .modes: return "Play"
        case .create: return "Create"
        }
    }

    var icon: String {
        switch self {
        case .feed: return "person.3.fill"
        case .modes: return "gamecontroller.fill"
        case .create: return "wand.and.stars"
        }
    }
}
