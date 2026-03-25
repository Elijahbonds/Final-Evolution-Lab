import SwiftUI

/// Scout / recruiter portal — season CSV from `PRQManager.exportSeasonStatsCSV()` (PRQ history, biometric scales, coach Peak Z / fatigue).
struct ScoutsPortalView: View {
    let viewModel: LabViewModel
    @State private var showPerformanceShare = false
    @State private var performanceShareItems: [Any] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("SCOUT'S PORTAL")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Theme.brandCyan.opacity(0.9))

                Text("Exports PRQ history, last biometric scales (readiness export), and PerformanceHistory proxies from the AI Coach JSON (Peak Z cm/s, fatigue state) into one CSV for recruiters and staff.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Button {
                    PRQManager.shared.sync(from: viewModel)
                    let csv = PRQManager.shared.exportSeasonStatsCSV()
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("FEL_SeasonStats_\(UUID().uuidString).csv")
                    do {
                        try csv.write(to: url, atomically: true, encoding: .utf8)
                        performanceShareItems = [url]
                        showPerformanceShare = true
                    } catch {
                        performanceShareItems = [csv]
                        showPerformanceShare = true
                    }
                } label: {
                    Label {
                        Text("Share Performance Report")
                            .font(.body.weight(.semibold))
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Theme.brandCyan)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandCyan)

                Text("Uses `UIActivityViewController` — AirDrop, Mail, Files, and more.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .background(Theme.deepBlack)
        .navigationTitle("Scout's Portal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            PRQManager.shared.sync(from: viewModel)
        }
        .sheet(isPresented: $showPerformanceShare) {
            ActivityShareSheet(items: performanceShareItems)
        }
    }
}
