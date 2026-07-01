import SwiftUI

/// Body IQ Education Lab — Bonds Standard prescriptions, NEXUS education preview, optional feed discovery post.
struct BodyIQEducationLabView: View {
    let viewModel: LabViewModel

    @State private var snacks: [MovementSnack] = []
    @State private var sharingSnack: MovementSnack?
    @State private var isPosting: Bool = false

    @StateObject private var service = AnatomyEducationService.shared
    @State private var eligibility: KinesiologyEligibility?
    @State private var isSolvingCoursework = false
    @State private var devErrorMessage: String?

    private var audit: BiomechanicsAudit {
        viewModel.biomechanicsAudit ?? .previewNeutral
    }

    private var neuralFocus01: Double {
        let m = viewModel.effectiveMetrics
        return min(1.0, max(0, (m.neuralDrive + m.readinessScore) / 200.0))
    }

    /// True when the current Lab scan supports biomechanical prescription — athlete-specific social framing allowed.
    private var measuredScanForSocialClaims: Bool {
        viewModel.profile.systemScan?.supportsBiomechanicalPrescription == true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                movementMiniSelfSection
                NavigationLink {
                    DrawingInTutorialView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.flexibility")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Theme.brandCyan.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DRAWING IN MODULE")
                                .font(.system(.caption2, design: .monospaced, weight: .black))
                                .foregroundStyle(Theme.brandCyan)
                                .tracking(2)
                            Text("Staggered V · torque → hike → tuck + IAP breath-sync")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.brandCyan.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BondsStandardCoachView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.elitePurple)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Theme.elitePurple.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BONDS STANDARD COACH")
                                .font(.system(.caption2, design: .monospaced, weight: .black))
                                .foregroundStyle(Theme.elitePurple)
                                .tracking(2)
                            Text("Full cue stack: V-stance → torque → hike → tuck → drawing-in")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.elitePurple.opacity(0.28), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AcademicLessonRunnerView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Theme.brandBlue.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ACADEMIC LESSON RUNNER")
                                .font(.system(.caption2, design: .monospaced, weight: .black))
                                .foregroundStyle(Theme.brandBlue)
                                .tracking(2)
                            Text("Common Core & STEM Sports Science Tracks")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.brandBlue.opacity(0.28), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                // APPLIED KINESIOLOGY CERTIFICATION SECTION
                certificationSection

                // DEVELOPER PANEL OVERRIDES CARD
                developerOverridesSection

                MovementSnackOverlayView(
                    audit: audit,
                    neuralFocus01: neuralFocus01,
                    onHotspotTap: { _ in }
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.brandCyan.opacity(0.5), Theme.elitePurple.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground)
                )

                Text("PROPRIOCEPTIVE PULSE RATE")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandCyan.opacity(0.8))
                    .tracking(2)

                Text(pulseCaption)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))

                ForEach(snacks) { snack in
                    snackCard(snack)
                }
            }
            .padding()
        }
        .background(Theme.deepBlack)
        .navigationTitle("Body IQ Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 4) {
                    Text("Body IQ Lab")
                        .font(.headline)
                    FELPreviewLabel(text: FELPremiumCopy.Preview.nexusEducation)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            reloadSnacks()
            Task {
                await loadEligibility()
            }
        }
    }

    private func loadEligibility() async {
        do {
            eligibility = try await service.getEligibility()
        } catch {
            print("Failed to fetch eligibility: \(error)")
        }
    }

    private var certificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "award.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.brandCyan)
                    
                VStack(alignment: .leading, spacing: 2) {
                    Text("BOARD CERTIFICATION")
                        .font(.system(.caption2, design: .monospaced, weight: .black))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)
                    Text("Applied Kinesiology Standard")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            
            Text("Earn your clinical credentials. Complete all four eligibility gates to unlock the final proctored exam.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            
            if let elig = eligibility {
                VStack(spacing: 12) {
                    EligibilityGateRow(
                        title: "1. Coursework Completed",
                        detail: elig.checks.courseworkCompleted.detail,
                        met: elig.checks.courseworkCompleted.met
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        EligibilityGateRow(
                            title: "2. Bio-Digital Overlays",
                            detail: elig.checks.bioDigitalModules.detail,
                            met: elig.checks.bioDigitalModules.met
                        )
                        
                        if !elig.checks.bioDigitalModules.met {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("STUDY OVERLAYS:")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.top, 4)
                                
                                ForEach(["skeletal_basics", "muscular_chains", "kinetic_chain_pillars", "neural_priming"], id: \.self) { mid in
                                    NavigationLink {
                                        BioDigitalAnatomyView(moduleId: mid)
                                    } label: {
                                        HStack {
                                            Text(mid.uppercased().replacingOccurrences(of: "_", with: " "))
                                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                                .foregroundStyle(Theme.brandCyan)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 8))
                                                .foregroundStyle(Theme.brandCyan)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.brandCyan.opacity(0.06)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                    
                    EligibilityGateRow(
                        title: "3. PRQ Score Threshold",
                        detail: elig.checks.prqThreshold.detail,
                        met: elig.checks.prqThreshold.met
                    )
                    
                    EligibilityGateRow(
                        title: "4. Final Assessment Passed",
                        detail: elig.checks.finalAssessment.detail,
                        met: elig.checks.finalAssessment.met
                    )
                }
                .padding(.vertical, 8)
                
                if elig.checks.finalAssessment.met {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.brandCyan)
                        Text("CERTIFICATION COMPLETED & VERIFIED")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.brandCyan.opacity(0.12)))
                } else {
                    let finalEligible = elig.checks.courseworkCompleted.met &&
                                        elig.checks.bioDigitalModules.met &&
                                        elig.checks.prqThreshold.met
                    
                    if finalEligible {
                        NavigationLink {
                            KinesiologyFinalAssessmentView()
                        } label: {
                            Text("START FINAL ASSESSMENT")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing)
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Complete gates 1, 2, and 3 to unlock assessment")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            } else {
                ProgressView()
                    .tint(Theme.brandCyan)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }

    private var developerOverridesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEV TOOLKIT: OVERRIDES")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.orange)
                .tracking(2)
            
            HStack(spacing: 8) {
                Text("TOKEN:")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Session Token", text: $service.sessionToken)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            Button {
                Task {
                    isSolvingCoursework = true
                    devErrorMessage = nil
                    do {
                        try await service.solveKinesiologyCoursework()
                        try await loadEligibility()
                        FelToastCenter.shared.show("Coursework solved successfully!", isError: false)
                    } catch {
                        devErrorMessage = error.localizedDescription
                    }
                    isSolvingCoursework = false
                }
            } label: {
                HStack {
                    if isSolvingCoursework {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                    }
                    Text("MOCK SOLVE COURSEWORK")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Capsule().fill(.orange))
            }
            .disabled(isSolvingCoursework)
            
            if let error = devErrorMessage {
                Text(error)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EligibilityGateRow: View {
    let title: String
    let detail: String
    let met: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(met ? Theme.brandCyan : Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(met ? .white : .white.opacity(0.6))
                Text(detail)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(met ? Theme.brandCyan.opacity(0.8) : .white.opacity(0.4))
            }
            Spacer()
        }
    }
}
extension BodyIQEducationLabView {

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOVEMENT SNACKS")
                .font(.system(.caption2, design: .monospaced, weight: .black))
                .foregroundStyle(Theme.brandBlue)
                .tracking(3)
            Text("Dynamic bio-feedback — map → position → breath.")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            if !measuredScanForSocialClaims {
                Text("No measured Lab audit on file — Movement Snack posts to the feed will be labeled general education, not athlete-specific findings.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.85))
                    .padding(.top, 4)
            }
        }
    }

    private var movementMiniSelfSection: some View {
        NexusMiniSelfPreviewView(
            profile: viewModel.profile,
            motionNote: FELPremiumCopy.Preview.simulatedPose,
            prqLabel: NexusMiniSelfPreviewView.prqPrescriptionLabel(for: viewModel.profile)
        )
    }

    private var pulseCaption: String {
        let period = MovementSnackEngine.proprioceptivePulsePeriodSeconds(neuralFocus01: neuralFocus01)
        if neuralFocus01 < 0.42 {
            return String(format: "Calm cadence — pulses slowed to ~%.1fs for nervous-system downshift.", period)
        }
        return String(format: "Arcade tempo — cues cycling ~%.1fs for locked-in focus.", period)
    }

    private func reloadSnacks() {
        let nf = audit.neuralFocusHint(from: viewModel)
        snacks = MovementSnackEngine.snacks(from: audit, neuralFocus01: nf)
    }

    private func snackCard(_ snack: MovementSnack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snack.title.uppercased())
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                    Text(snack.subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text("\(snack.durationSeconds)s")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.brandCyan.opacity(0.12)))
            }

            phaseRow("A · MAP", snack.phaseMappingCarsCue, color: Theme.brandBlue)
            phaseRow("B · POSITION", "NEXUS: \(snack.correctivePoseAssetID)", color: Theme.elitePurple)
            phaseRow("C · BREATH", snack.phaseBreathCue, color: Theme.brandCyan)

            Text("Early Access · \(snack.requiredAnimationAssetID)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 10) {
                Button {
                    // NEXUS education preview — cue retained for future C++ education port.
                    FelToastCenter.shared.show("Cue queued for NEXUS education preview", isError: false)
                } label: {
                    Text("QUEUE NEXUS CUE")
                        .font(.system(.caption, design: .monospaced, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing)
                            )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await shareDiscovery(snack) }
                } label: {
                    HStack(spacing: 6) {
                        if isPosting && sharingSnack?.id == snack.id {
                            ProgressView()
                                .tint(Theme.brandCyan)
                                .scaleEffect(0.8)
                        }
                        Text(measuredScanForSocialClaims ? "POST DISCOVERY" : "POST (GENERAL)")
                            .font(.system(.caption, design: .monospaced, weight: .heavy))
                    }
                    .foregroundStyle(Theme.brandCyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .stroke(Theme.brandCyan.opacity(0.45), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isPosting)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func phaseRow(_ title: String, _ body: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
            Text(body)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareDiscovery(_ snack: MovementSnack) async {
        guard !isPosting else { return }
        isPosting = true
        sharingSnack = snack
        defer {
            isPosting = false
            sharingSnack = nil
        }
        do {
            let provenance: MovementSnackFeedProvenance =
                measuredScanForSocialClaims ? .measuredAthleteSpecific : .generalEducation
            try await TrainingLabSocialBridge.shared.publishMovementSnackDiscovery(
                snack: snack,
                athleteDisplayName: viewModel.profile.displayName,
                provenance: provenance
            )
            FelToastCenter.shared.show("Discovery posted to Lab feed", isError: false)
        } catch {
            FelToastCenter.shared.show(error.localizedDescription, isError: true)
        }
    }
}

private extension BiomechanicsAudit {
    func neuralFocusHint(from vm: LabViewModel) -> Double? {
        let m = vm.effectiveMetrics
        return min(1.0, max(0, (m.neuralDrive + m.readinessScore) / 200.0))
    }
}
