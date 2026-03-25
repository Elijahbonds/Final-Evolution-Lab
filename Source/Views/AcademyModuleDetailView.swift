import SwiftUI

// MARK: - Full module detail: body, takeaways, correctives, phase, and link to Training.

struct AcademyModuleDetailView: View {
    let module: VerticalVelocityModule
    var viewModel: LabViewModel
    var onOpenTraining: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    private let accent = Theme.brandCyan

    private var isModuleComplete: Bool {
        viewModel.profile.completedAcademyModuleIds.contains(module.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerBlock
                if !module.keyTakeaways.isEmpty {
                    takeawaysBlock
                }
                if let bodyText = module.detailBody {
                    bodyBlock(bodyText)
                }
                toolsBlock
                if let corrective = module.correctivePair {
                    correctiveBlock(corrective)
                }
                if module.phase != nil || module.estimatedMinutes != nil {
                    metaRow
                }
                markCompleteSection
                if onOpenTraining != nil {
                    practiceButton
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Theme.deepBlack)
        .navigationTitle(module.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mod \(module.number)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .tracking(2)
            Text(module.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Text(module.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(module.learningObjective)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var takeawaysBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KEY TAKEAWAYS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .tracking(2)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(module.keyTakeaways.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(accent)
                        Text(line)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func bodyBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LESSON")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
    }

    private var toolsBlock: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 12))
                .foregroundStyle(accent)
            Text("Tools: \(module.tools)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent.opacity(0.12))
        )
    }

    private func correctiveBlock(_ corrective: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(Theme.foundationGreen)
            VStack(alignment: .leading, spacing: 4) {
                Text("CORRECTIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text(corrective)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.foundationGreen.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.foundationGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var metaRow: some View {
        HStack(spacing: 16) {
            if let phase = module.phase {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accent)
                    Text(phase)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            if let min = module.estimatedMinutes {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(min) min")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
    }

    private var markCompleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if module.id == "mod9" {
                Text("Completing Plyos unlocks +2% neuro potential in Dunk Contest (Swift + Unreal `academyPlyosMasteryBonus`).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Button {
                viewModel.markAcademyModuleComplete(module.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isModuleComplete ? "checkmark.seal.fill" : "seal")
                    Text(isModuleComplete ? "Module completed" : "Mark module complete")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                }
                .foregroundStyle(isModuleComplete ? Theme.foundationGreen : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isModuleComplete ? Theme.foundationGreen.opacity(0.2) : accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(isModuleComplete)
        }
    }

    private var practiceButton: some View {
        Button {
            onOpenTraining?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                Text("Practice in Training")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}
