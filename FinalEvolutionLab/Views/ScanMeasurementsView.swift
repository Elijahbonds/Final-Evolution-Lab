import SwiftUI

/// Lift-App-parity body-segment measurement HUD + optimal-form joint overlay
/// readout. Pure SwiftUI over ``ScanFormAnalysis`` (no capture/scenekit deps) so
/// it renders even when the 3D replay cannot.
struct ScanMeasurementsView: View {
    let analysis: ScanFormAnalysis

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.2).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        honestyBanner
                        segmentPanel
                        jointOverlayPanel
                        if !analysis.leakageZones.isEmpty {
                            leakagePanel
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Body Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationBackground(Theme.deepBlack)
    }

    private var honestyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: analysis.isMeasured ? "checkmark.seal.fill" : "info.circle.fill")
                .foregroundStyle(analysis.isMeasured ? Theme.brandCyan : .orange)
            Text(analysis.isMeasured
                 ? "Derived from your measured scan."
                 : "Demo scan — segment lengths & angles are illustrative (rig proportions), not a measured body mesh.")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
    }

    // MARK: - Segments

    private var segmentPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("SEGMENT LENGTHS", icon: "ruler.fill")

            ForEach(analysis.segments) { segment in
                VStack(spacing: 6) {
                    HStack {
                        Text(segment.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "%.2f m", segment.lengthMeters))
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                        Text(String(format: "%.0f%%", segment.proportionPercent))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 42, alignment: .trailing)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(LinearGradient(colors: [Theme.brandBlue, Theme.brandCyan],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * barFraction(segment.proportionPercent))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
    }

    /// Map 70…130% proportion onto a 0…1 bar so neutral (100%) sits mid-bar.
    private func barFraction(_ pct: Double) -> Double {
        min(1.0, max(0.05, (pct - 70.0) / 60.0))
    }

    // MARK: - Joint overlay (optimal-form deviations)

    private var jointOverlayPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("OPTIMAL-FORM OVERLAY", icon: "scope")

            Text("Your captured joint angles vs athletic ideal. Off-target joints are flagged for the 3D overlay.")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)

            ForEach(analysis.joints) { joint in
                HStack(spacing: 12) {
                    Circle()
                        .fill(ScanFormReplayView.verdictColor(joint.verdict))
                        .frame(width: 12, height: 12)
                        .shadow(color: ScanFormReplayView.verdictColor(joint.verdict).opacity(0.6), radius: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(joint.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(verdictLabel(joint.verdict))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(ScanFormReplayView.verdictColor(joint.verdict))
                            .tracking(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f°", joint.angleDeg))
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(String(format: "ideal %.0f° · %+.0f°", joint.idealDeg, joint.deviationDeg))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(ScanFormReplayView.verdictColor(joint.verdict).opacity(0.06)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
    }

    private func verdictLabel(_ v: ScanFormAnalysis.JointReadout.Verdict) -> String {
        switch v {
        case .good: return "ON TARGET"
        case .watch: return "WATCH"
        case .off: return "OFF TARGET"
        }
    }

    // MARK: - Kinetic leakage

    private var leakagePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("KINETIC-LEAKAGE ZONES", icon: "bolt.trianglebadge.exclamationmark.fill")

            ForEach(analysis.leakageZones) { zone in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: zone.joint.systemImage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.orange)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(zone.joint.displayName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(String(format: "%.0f%% leak", zone.severity * 100))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                        Text(zone.description)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.06)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.brandCyan)
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)
        }
    }
}
