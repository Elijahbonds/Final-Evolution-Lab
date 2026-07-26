import SwiftUI

/// Dashboard entry: capture pose/motion → NEXUS arena generation with honest preview labeling.
struct ScanToGenerateView: View {
    let onGenerated: ((ScanToGenerationBridge.GenerationResult) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var captureService = ScanCaptureService()
    @State private var generationResult: ScanToGenerationBridge.GenerationResult?
    @State private var isSubmitting = false

    init(onGenerated: ((ScanToGenerationBridge.GenerationResult) -> Void)? = nil) {
        self.onGenerated = onGenerated
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.25).ignoresSafeArea()

                VStack(spacing: 20) {
                    header
                    content
                    actionButton
                }
                .padding()
            }
            .navigationTitle("Scan to Generate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        captureService.cancelCapture()
                        dismiss()
                    }
                    .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
    }

    private var header: some View {
        VStack(spacing: 10) {
            FELPreviewLabel(text: captureService.previewLabel)

            Text("Athlete scan → NEXUS arena")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)

            Text("Uses Vision body pose, ARKit when available, or CoreMotion — not MetaHuman mesh retargeting. Generated voxels and difficulty are fitness-proportional previews.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch captureService.phase {
        case .idle:
            idlePanel
        case .capturing(let progress):
            capturingPanel(progress: progress)
        case .complete(let envelope):
            completePanel(envelope: envelope)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        }
    }

    private var idlePanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand.line.dotted.figure.stand")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Theme.brandCyan)
                .symbolEffect(.pulse)

            HStack(spacing: 12) {
                featurePill("JOINT ANGLES", icon: "angle")
                featurePill("REACH", icon: "arrow.up.left.and.arrow.down.right")
                featurePill("FRC PROXY", icon: "waveform.path.ecg")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func capturingPanel(progress: Double) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 4)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.brandCyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Text(captureService.usesSimulation ? "SIMULATING POSE + MOTION" : "CAPTURING POSE + MOTION")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)
        }
    }

    private func completePanel(envelope: ScanEnvelope) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if let generationResult {
                    resultCard(generationResult)
                } else {
                    envelopeCard(envelope)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func envelopeCard(_ envelope: ScanEnvelope) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCAN ENVELOPE READY")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)

            metricRow("Source", envelope.source.rawValue.uppercased())
            metricRow("Confidence", String(format: "%.0f%%", envelope.confidence01 * 100))
            metricRow("Knee L/R", String(format: "%.0f° / %.0f°", envelope.joints.leftKneeAngleDeg, envelope.joints.rightKneeAngleDeg))
            metricRow("Reach L/R", String(format: "%.0f%% / %.0f%%", envelope.joints.leftShoulderReach01 * 100, envelope.joints.rightShoulderReach01 * 100))
            metricRow("Vertical est.", String(format: "%.1f\"", envelope.motion.verticalEstimateInches))
            metricRow("Flight est.", String(format: "%.2fs", envelope.motion.flightTimeSeconds))

            Text("Tap Generate to turn your scan into arena layout and difficulty settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
    }

    private func resultCard(_ result: ScanToGenerationBridge.GenerationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FELPreviewLabel(text: result.previewLabel)

            Text("ARENA GENERATED")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.neonGreen)
                .tracking(2)

            metricRow("Arena scale", String(format: "%.2fx", result.arenaScale))
            metricRow("Difficulty", "Tier \(result.difficultyTier)")
            metricRow("Mode hint", result.recommendedModeId.replacingOccurrences(of: "_", with: " ").uppercased())
            metricRow("Voxel paint", "Material \(result.voxelMaterial) · r=\(result.paintRadius)")

            Text("Commands: \(result.commandsApplied.joined(separator: ", "))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.neonGreen.opacity(0.25)))
        )
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func featurePill(_ label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
        }
        .foregroundStyle(Theme.brandCyan.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.brandCyan.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var actionButton: some View {
        switch captureService.phase {
        case .idle:
            Button {
                captureService.startCapture()
            } label: {
                label("START SCAN", icon: "camera.viewfinder")
            }
        case .capturing:
            EmptyView()
        case .complete:
            if generationResult == nil {
                Button {
                    guard case .complete(let envelope) = captureService.phase else { return }
                    isSubmitting = true
                    Task {
                        let result = ScanToGenerationBridge.submit(envelope: envelope)
                        await MainActor.run {
                            isSubmitting = false
                            generationResult = result
                            if let result {
                                onGenerated?(result)
                            }
                        }
                    }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        label("GENERATE ARENA", icon: "sparkles")
                    }
                }
                .disabled(isSubmitting)
            } else {
                Button {
                    dismiss()
                } label: {
                    label("DONE", icon: "checkmark")
                }
            }
        case .failed:
            Button { captureService.startCapture() } label: {
                label("RETRY SCAN", icon: "arrow.clockwise")
            }
        }
    }

    private func label(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(.subheadline, design: .monospaced, weight: .black))
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.brandCyan)
        .clipShape(.rect(cornerRadius: 14))
    }
}
