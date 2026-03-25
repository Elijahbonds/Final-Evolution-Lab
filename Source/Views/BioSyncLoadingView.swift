import SwiftUI

/// Swift → Unreal handoff after System Scan: re-sync readiness JSON, then broadcast Bio-Sync complete.
struct BioSyncLoadingView: View {
    var viewModel: LabViewModel
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0
    @State private var labelOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Theme.deepBlack, Color(red: 0.02, green: 0.04, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .stroke(Theme.brandCyan.opacity(0.25), lineWidth: 3)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: phase)
                        .stroke(
                            LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                }

                Text("BIO-SYNC")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(Theme.foundationGreen)

                Text("Syncing your digital twin to the Lab…")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .opacity(labelOpacity)

                Text("readiness_snapshot.json → Documents/FEL/")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .opacity(labelOpacity)
            }
        }
        .onAppear {
            PRQManager.shared.sync(from: viewModel)
            if reduceMotion {
                phase = 1
                labelOpacity = 1
                finishHandshake()
            } else {
                withAnimation(.easeInOut(duration: 1.2).repeatCount(1, autoreverses: false)) {
                    phase = 1
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                    labelOpacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                    finishHandshake()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felBioSyncComplete)) { _ in
            FELHaptics.bioSyncCompleteSuccess()
        }
    }

    private func finishHandshake() {
        // Scan flow awaits `nominalVideoFrameRateHz` before showing results; `applyScanResult` persists `SystemScanResult`.
        // Sync here so `readiness_snapshot.json` includes kinetic heat and `videoNominalFrameRateHz` before Bio-Sync.
        PRQManager.shared.sync(from: viewModel)
        let url = PRQManager.shared.lastExportURL
        FELBirthReadinessWriter.notifyBioSyncComplete(snapshotURL: url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onFinished()
        }
    }
}
