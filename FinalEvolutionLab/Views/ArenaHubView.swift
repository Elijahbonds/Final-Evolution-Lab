import SwiftUI

struct ArenaHubView: View {
    var viewModel: LabViewModel
    @State private var segment: ArenaSegment = .feed

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $segment) {
                ForEach(ArenaSegment.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Group {
                switch segment {
                case .feed:
                    CommunityFeedView()
                case .modes:
                    GameModeSelectionView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.deepBlack)
    }
}

private enum ArenaSegment: String, CaseIterable, Identifiable {
    case feed
    case modes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: return "Community"
        case .modes: return "Modes"
        }
    }
}
