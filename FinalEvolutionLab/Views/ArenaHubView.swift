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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

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
        .background(Theme.deepBlack)
    }

    private var arenaSegmentPicker: some View {
        HStack(spacing: 6) {
            ForEach(ArenaSegment.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        segment = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(segment == tab ? .black : .white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(segment == tab ? tab.accentColor : Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ArenaSegment_\(tab.rawValue)")
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Theme.slateCard)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
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

    var accentColor: Color {
        switch self {
        case .feed: return Theme.brandBlue
        case .modes: return Theme.neonGreen
        case .create: return Theme.elitePurple
        }
    }
}
