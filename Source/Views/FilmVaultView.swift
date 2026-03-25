import SwiftUI

/// Sport film review: dual-player sync, overlays, and analyst checkpoints (see product spec).
/// Full implementation wires AVFoundation + Canvas; this screen anchors navigation and XP hooks.
struct FilmVaultView: View {
    var viewModel: LabViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("FILM VAULT")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.brandCyan)
                Text("Biomechanical overlays on sport film")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Compare athlete vs pro reference with synced scrubbing, force vectors, and joint-angle arcs. Export analyst JSON checkpoints.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.split.2x1.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.brandBlue.opacity(0.8))
                            Text("Dual video + telestrator (coming online)")
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
