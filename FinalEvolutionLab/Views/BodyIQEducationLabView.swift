import SwiftUI

/// Body IQ Education Lab — Bonds Standard prescriptions, Unreal hooks, optional feed discovery post.
struct BodyIQEducationLabView: View {
    let viewModel: LabViewModel

    @State private var snacks: [MovementSnack] = []
    @State private var sharingSnack: MovementSnack?
    @State private var isPosting: Bool = false

    private var audit: BiomechanicsAudit {
        viewModel.biomechanicsAudit ?? .empty
    }

    private var neuralFocus01: Double {
        let m = viewModel.effectiveMetrics
        return min(1.0, max(0, (m.neuralDrive + m.readinessScore) / 200.0))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            reloadSnacks()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOVEMENT SNACKS")
                .font(.system(.caption2, design: .monospaced, weight: .black))
                .foregroundStyle(Theme.brandBlue)
                .tracking(3)
            Text("Dynamic bio-feedback — map → position → breath.")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
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
            phaseRow("B · POSITION", "Unreal: \(snack.unrealCorrectivePoseAssetID)", color: Theme.elitePurple)
            phaseRow("C · BREATH", snack.phaseBreathCue, color: Theme.brandCyan)

            Text("UE · \(snack.requiredUnrealAnimationAssetID)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 10) {
                Button {
                    NexusBridge.shared.deliverBodyIQSnackJSON(snack)
                    FelToastCenter.shared.show("Cue stack sent to Unreal bridge", isError: false)
                } label: {
                    Text("SEND TO UNREAL")
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
                        Text("POST DISCOVERY")
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
            try await TrainingLabSocialBridge.shared.publishMovementSnackDiscovery(
                snack: snack,
                athleteDisplayName: viewModel.profile.displayName
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
