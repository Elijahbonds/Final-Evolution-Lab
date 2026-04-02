import SwiftUI
import AVKit

/// Bundled magic reveal venue videos for the Final Evolution Lab iOS app.
/// These are automatically included via Xcode 16's file-system synchronized groups.
enum MagicRevealVideo: String, CaseIterable, Identifiable {
    case veniceCourt = "Venice_Beach_Court_magic_reveal"
    case veniceBallShop = "Venice_Ball_Shop_magic_reveal"
    case muscleBeachGym = "Muscle_beach_gym_magic_reveal"
    case muscleBeachStage = "Muscle_beach_stage_magic_reveal"
    case tennisCourts = "Venice_beach_tennis_courts_magic_reveal"
    case blackTop = "Venice_Beach_Black_Top_magic_reveal"
    case hoopbus = "Hoopbus_magic_reveal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .veniceCourt: return "Venice Beach Court"
        case .veniceBallShop: return "Venice Ball Shop"
        case .muscleBeachGym: return "Muscle Beach Gym"
        case .muscleBeachStage: return "Muscle Beach Stage"
        case .tennisCourts: return "Venice Tennis Courts"
        case .blackTop: return "Venice Beach Black Top"
        case .hoopbus: return "Hoopbus"
        }
    }

    var url: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "mp4")
    }

    var player: AVPlayer? {
        guard let url = url else { return nil }
        return AVPlayer(url: url)
    }
}

/// SwiftUI view for playing a magic reveal video
struct MagicRevealPlayerView: View {
    let video: MagicRevealVideo
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                VStack {
                    Image(systemName: "film.slash")
                        .font(.largeTitle)
                    Text("Video not found")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            player = video.player
        }
    }
}

/// Grid view showing all magic reveal videos
struct MagicRevealGalleryView: View {
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(MagicRevealVideo.allCases) { video in
                        NavigationLink(destination: MagicRevealPlayerView(video: video)
                            .navigationTitle(video.displayName)
                            .ignoresSafeArea()
                        ) {
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)

                                Text(video.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Magic Reveal Videos")
        }
    }
}
