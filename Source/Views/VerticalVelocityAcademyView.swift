import SwiftUI

// MARK: - Vertical Velocity Academy — 12 modules (emulator / education integration)
// Syllabus and lesson scripts can be expanded; correctives and tools linked to Training.

struct VerticalVelocityAcademyView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: LabViewModel
    private let modules = VerticalVelocityAcademyCurriculum.modules
    /// When set, "Practice in Training" in module detail will dismiss and switch to Training tab.
    var onOpenTraining: (() -> Void)?
    /// Deep-link from System Scan "Fix this" (`mod1`…`mod12`).
    var initialModuleId: String? = nil

    @State private var selectedModule: VerticalVelocityModule?

    private var prescription: AcademyPrescriptionEngine.Prescription {
        let h = AcademyPrescriptionEngine.heatTriple(from: viewModel.biomechanicsAudit)
        return AcademyPrescriptionEngine.compute(
            ankleHeat: h.0,
            kneeHeat: h.1,
            hipHeat: h.2,
            sfmaMultiSegmentalRotationPassed: viewModel.profile.systemScan?.sfmaMultiSegmentalRotationPassed
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock
                    prescriptionBlock
                    phaseSection("Foundations", modNumbers: [1, 2, 3, 4, 5, 6])
                    phaseSection("Load & Launch", modNumbers: [7, 8])
                    phaseSection("Flight & Blueprint", modNumbers: [9, 10])
                    phaseSection("Fuel & Tools", modNumbers: [11, 12])
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
            .onAppear {
                if selectedModule == nil, let id = initialModuleId, let mod = VerticalVelocityAcademyCurriculum.module(id: id) {
                    selectedModule = mod
                }
            }
            .navigationDestination(item: $selectedModule) { mod in
                AcademyModuleDetailView(
                    module: mod,
                    viewModel: viewModel,
                    onOpenTraining: {
                        dismiss()
                        onOpenTraining?()
                    }
                )
            }
        }
    }

    private func phaseSection(_ title: String, modNumbers: [Int]) -> some View {
        let filtered = modules.filter { modNumbers.contains($0.number) }
        guard !filtered.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue.opacity(0.9))
                    .tracking(2)
                ForEach(filtered) { mod in
                    Button {
                        selectedModule = mod
                    } label: {
                        moduleCard(mod, prescription: prescription)
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    private var prescriptionBlock: some View {
        let p = prescription
        return VStack(alignment: .leading, spacing: 10) {
            Text("PRESCRIPTION (FROM SCAN)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.foundationGreen)
                .tracking(2)
            Text(p.rationale)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if !p.highPriorityModuleIds.isEmpty {
                Text("High priority: " + p.highPriorityModuleIds.joined(separator: ", "))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.foundationGreen)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.foundationGreen.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.foundationGreen.opacity(0.25), lineWidth: 1))
        )
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

    private func moduleCard(_ mod: VerticalVelocityModule, prescription: AcademyPrescriptionEngine.Prescription) -> some View {
        let isHigh = prescription.highPriorityModuleIds.contains(mod.id)
        let isMed = prescription.mediumPriorityModuleIds.contains(mod.id)
        return VStack(alignment: .leading, spacing: 10) {
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
                if isHigh {
                    Text("PRIORITY")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.foundationGreen)
                        .clipShape(Capsule())
                } else if isMed {
                    Text("SUPPORT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.brandCyan.opacity(0.15))
                        .clipShape(Capsule())
                }
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
