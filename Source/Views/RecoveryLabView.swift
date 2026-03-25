// MARK: - Recovery Lab — Readiness, audit-based suggestions, Neural Decompression & Myofascial Reset

import SwiftUI

struct RecoveryLabView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    private var audit: BiomechanicsAudit? { viewModel.biomechanicsAudit }
    private var readiness: Double { viewModel.effectiveMetrics.readinessScore }
    private var suggestedFocus: [String] {
        var list: [String] = []
        guard let audit = audit else {
            list.append("Run a System Scan to get personalized recovery suggestions.")
            return list
        }
        if audit.ankleDorsiflexion.status == .deficit || audit.kineticLeakageZones.contains(where: { $0.joint == .ankle }) {
            list.append("Ankle stiffness — add calf rolls and ankle mobility before bed.")
        }
        if audit.hipExtension.status == .deficit || audit.kineticLeakageZones.contains(where: { $0.joint == .hip }) {
            list.append("Hip extension — focus on posterior chain release and hip flexor lengthening.")
        }
        if audit.kneeTracking.status == .deficit || audit.kineticLeakageZones.contains(where: { $0.joint == .knee }) {
            list.append("Knee tracking — single-leg balance and VMO work on recovery days.")
        }
        if audit.kineticLeakageZones.contains(where: { $0.description.lowercased().contains("flight") || $0.description.lowercased().contains("reactive") }) {
            list.append("Reactive strength — keep ground-contact drills light on recovery days.")
        }
        if list.isEmpty {
            list.append("Kinetic chain looks primed. Use recovery for neural decompression and tissue quality.")
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    readinessCard
                    auditSuggestionsCard
                    neuralDecompressionCard
                    myofascialResetCard
                }
                .padding()
            }
            .background(Theme.deepBlack)
            .navigationTitle("Recovery Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                        .accessibilityHint("Closes Recovery Lab")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var readinessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Neural Readiness", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(Theme.brandBlue)
            Text("Your readiness score reflects how recovered your nervous system is. Train hard when it's high; prioritize recovery when it's low.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Text("\(Int(readiness))%")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(readinessColor)
                Spacer()
                Text(readinessLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
            )
        }
    }

    private var readinessColor: Color {
        if readiness >= 70 { return Theme.neonGreen }
        if readiness >= 50 { return .orange }
        return .red
    }

    private var readinessLabel: String {
        if readiness >= 70 { return "Ready to perform" }
        if readiness >= 50 { return "Moderate — consider lighter load" }
        return "Prioritize recovery today"
    }

    private var auditSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("From Your Biomechanics Audit", systemImage: "figure.stand")
                .font(.headline)
                .foregroundStyle(Theme.brandCyan)
            Text("Personalized focus areas based on your latest movement scan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(suggestedFocus.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.brandCyan)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
            )
        }
    }

    private var neuralDecompressionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Neural Decompression", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundStyle(Theme.brandBlue)
            Text("Guided breathing and posterior chain release to downregulate the nervous system and improve recovery between sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brandBlue)
                Text("Coming soon: 5–10 min guided flows")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
            )
        }
    }

    private var myofascialResetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Myofascial Reset", systemImage: "figure.massage")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Targeted trigger-point and mobility work based on your audit. Calves, quads, and thoracic for jumpers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Image(systemName: "circle.dashed")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Coming soon: audit-linked routines")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
            )
        }
    }
}
