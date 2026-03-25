import SwiftUI

/// Live / VOD instruction channel (Peloton-style). HLS playback + rep counter hooks into local pose pipeline when available.
struct EvolutionStreamChannelView: View {
    var viewModel: LabViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("EVOLUTION STREAM")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.elitePurple)
                Text("Live & on-demand coaching")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Ultra-low latency streams with instructor cues and live rep targets. Connect backend WebSocket for REP_GOAL signals.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 180)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.elitePurple.opacity(0.9))
                            Text("HLS player + leaderboard (placeholder)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Theme.deepBlack)
    }
}
