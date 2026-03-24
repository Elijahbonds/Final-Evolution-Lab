import SwiftUI

struct HRVStatPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .black))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }
}
