import SwiftUI

// MARK: - Vertical Velocity Academy — 12 modules (emulator / education integration)
// Syllabus and lesson scripts can be expanded; correctives and tools linked to Training.

struct VerticalVelocityAcademyView: View {
    @Environment(\.dismiss) private var dismiss
    private let modules = VerticalVelocityAcademyCurriculum.modules

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock
                    ForEach(modules) { mod in
                        moduleCard(mod)
                    }
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .background(Theme.deepBlack)
            .navigationTitle("Vertical Velocity Academy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.brandCyan)
                }
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CNS FREEWAY FRAMEWORK")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Theme.brandBlue)
                .accessibilityAddTraits(.isHeader)
            Text("The Central Nervous System is a freeway. Adhesions are roadblocks. Every drill clears the road to increase signal velocity.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.brandBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func moduleCard(_ mod: VerticalVelocityModule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("Mod \(mod.number)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mod.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(mod.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(mod.learningObjective)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
            Text("Tools: \(mod.tools)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.brandCyan.opacity(0.9))
            if let corrective = mod.correctivePair {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Corrective: \(corrective)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.brandBlue.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mod.displayTitle): \(mod.subtitle)")
        .accessibilityHint(mod.learningObjective)
    }
}
