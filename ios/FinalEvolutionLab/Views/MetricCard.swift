import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
