import SwiftUI

struct ParentalOverviewCard: View {
    let prqScore: Double
    let readinessScore: Double
    let evolutionShards: Int
    @Environment(\.simpleMode) private var simpleMode

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)

                Text("PARENT OVERVIEW")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)
                    .tracking(2)
            }

            HStack(spacing: 12) {
                overviewStat(
                    label: simpleMode ? "Fitness" : "PRQ",
                    value: String(format: "%.0f", prqScore),
                    icon: "heart.circle.fill",
                    color: prqColor
                )

                overviewStat(
                    label: simpleMode ? "Ready" : "Readiness",
                    value: String(format: "%.0f%%", readinessScore),
                    icon: "bolt.heart.fill",
                    color: readinessColor
                )

                overviewStat(
                    label: simpleMode ? "Points" : "Shards",
                    value: "\(evolutionShards)",
                    icon: "diamond.fill",
                    color: Theme.brandCyan
                )
            }

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandBlue.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func overviewStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(.white)

            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private var prqColor: Color {
        if prqScore >= 70 { return .green }
        if prqScore >= 40 { return .orange }
        return .red
    }

    private var readinessColor: Color {
        if readinessScore >= 70 { return .green }
        if readinessScore >= 40 { return .yellow }
        return .red
    }

    private var summaryText: String {
        if prqScore >= 70 {
            return "Great progress! Your athlete is performing at a high level with strong readiness indicators."
        } else if prqScore >= 40 {
            return "Solid foundation building. Consistent training will continue improving performance scores."
        } else {
            return "Just getting started! Regular sessions will quickly improve all performance metrics."
        }
    }
}
