import SwiftUI

/// Honest preview badge for NEXUS-only / stub surfaces (education, anatomy, streaming).
struct FELPreviewLabel: View {
    var text: String = FELPremiumCopy.Preview.appLayer

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(Theme.brandCyan.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Theme.brandCyan.opacity(0.12))
                    .overlay(Capsule().stroke(Theme.brandCyan.opacity(0.35), lineWidth: 1))
            )
    }
}
