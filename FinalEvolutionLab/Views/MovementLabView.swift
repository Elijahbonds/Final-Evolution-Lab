import SwiftUI

// MARK: - MovementLabView
// Bonds Bounce Blueprint education module — non-scoring, non-game session.
// Surfaces the 6-drill jump curriculum with PRQ-gated drill progression.
// Routes through GameModeRouter as .movementLab (kNonGameModule in C++ registry).

struct MovementLabView: View {
    let gameMode: GameMode

    @State private var completedDrills: Set<String> = []
    @State private var activeDrillId: String? = nil
    @State private var appeared = false
    @State private var showDrillDetail: DrillInfo? = nil

    private struct DrillInfo: Identifiable {
        let id: String
        let displayName: String
        let description: String
        let prqThreshold: Float
        let iconName: String
        let accentColor: Color
    }

    private static let drills: [DrillInfo] = [
        DrillInfo(id: "intro",         displayName: "Posture & Foot Placement",
                  description: "Build your base. Learn ideal foot-width, hip-neutral stance, and head position for maximum power transfer.",
                  prqThreshold: 0.50, iconName: "figure.stand",
                  accentColor: Color(red: 0.45, green: 0.65, blue: 1.0)),
        DrillInfo(id: "loading",       displayName: "Hip Hinge & Eccentric Load",
                  description: "Load the spring. Hinge at the hips, load your posterior chain, and feel the elastic energy build.",
                  prqThreshold: 0.60, iconName: "arrow.down.to.line",
                  accentColor: Color(red: 0.55, green: 0.55, blue: 0.95)),
        DrillInfo(id: "triple_ext",    displayName: "Triple Extension Mechanics",
                  description: "Explode through ankle, knee, and hip simultaneously. This is where vertical height is made.",
                  prqThreshold: 0.65, iconName: "bolt.fill",
                  accentColor: Color(red: 1.0, green: 0.65, blue: 0.25)),
        DrillInfo(id: "arm_drive",     displayName: "Arm Drive & Overhead Reach",
                  description: "Sync arm swing to triple extension for a 3–5 cm height bonus. Reach through the ceiling on every rep.",
                  prqThreshold: 0.65, iconName: "arrow.up.circle.fill",
                  accentColor: Color(red: 0.3, green: 0.85, blue: 0.6)),
        DrillInfo(id: "landing",       displayName: "Landing Absorption & Stack",
                  description: "Land soft, land strong. Stack ankle → knee → hip to absorb impact and protect your joints.",
                  prqThreshold: 0.70, iconName: "arrow.down.circle.fill",
                  accentColor: Color(red: 0.95, green: 0.45, blue: 0.45)),
        DrillInfo(id: "full_sequence", displayName: "Integrated Rep (PRQ Gate)",
                  description: "Put it all together: load → triple ext → arm drive → land. Earn your Movement IQ badge.",
                  prqThreshold: 0.75, iconName: "star.fill",
                  accentColor: Color(red: 1.0, green: 0.85, blue: 0.1)),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.12).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    FELPreviewLabel(message: "MOVEMENT LAB · PREVIEW — curriculum gates require live PRQ session")
                        .padding(.horizontal)
                    progressBar
                    drillsSection
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { appeared = true }
        }
        .sheet(item: $showDrillDetail) { drill in
            drillDetailSheet(drill)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MOVEMENT LAB")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Color(red: 0.45, green: 0.55, blue: 0.95))
                .tracking(4)
                .padding(.horizontal)
                .padding(.top, 16)

            Text("Bonds Bounce Blueprint")
                .font(.system(size: 36, weight: .black))
                .italic()
                .foregroundStyle(.white)
                .padding(.horizontal)

            Text("6 drills · PRQ feedback · jump mastery")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 2)
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(completedDrills.count) / \(Self.drills.count) DRILLS COMPLETE")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Spacer()
                Text("\(Int(Float(completedDrills.count) / Float(Self.drills.count) * 100))%")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Color(red: 0.45, green: 0.55, blue: 0.95))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.45, green: 0.55, blue: 0.95))
                        .frame(width: geo.size.width * CGFloat(completedDrills.count) / CGFloat(Self.drills.count), height: 6)
                        .animation(.spring(response: 0.5), value: completedDrills.count)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
    }

    // MARK: - Drills list

    private var drillsSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(Self.drills.enumerated()), id: \.element.id) { index, drill in
                let isComplete = completedDrills.contains(drill.id)
                let isActive   = activeDrillId == drill.id
                let isLocked   = index > 0 && !completedDrills.contains(Self.drills[index - 1].id)

                drillRow(drill: drill, index: index, isComplete: isComplete,
                         isActive: isActive, isLocked: isLocked)
            }
        }
        .padding(.horizontal)
    }

    private func drillRow(drill: DrillInfo, index: Int,
                          isComplete: Bool, isActive: Bool, isLocked: Bool) -> some View {
        Button {
            guard !isLocked else { return }
            showDrillDetail = drill
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isComplete ? drill.accentColor : Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    } else if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    } else {
                        Image(systemName: drill.iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(drill.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.displayName)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(isLocked ? Color.white.opacity(0.3) : .white)
                    Text("PRQ ≥ \(Int(drill.prqThreshold * 100))%\(isLocked ? " · Complete previous drill first" : "")")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(isLocked ? Color.white.opacity(0.2) : .secondary)
                }

                Spacer()

                if isComplete {
                    Text("DONE")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(drill.accentColor)
                        .tracking(2)
                } else if !isLocked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? drill.accentColor.opacity(0.15) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isActive ? drill.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.5 : 1.0)
    }

    // MARK: - Drill detail sheet

    @ViewBuilder
    private func drillDetailSheet(_ drill: DrillInfo) -> some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.12).ignoresSafeArea()
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(drill.accentColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: drill.iconName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(drill.accentColor)
                    }
                    .padding(.top, 32)

                    Text(drill.displayName)
                        .font(.system(size: 24, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(drill.description)
                        .font(.system(.body))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("PRQ gate: ≥ \(Int(drill.prqThreshold * 100))%")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(drill.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(drill.accentColor.opacity(0.12), in: Capsule())

                    FELPreviewLabel(message: "Live PRQ gating requires a NEXUS gameplay session")
                        .padding(.horizontal)

                    // Simulate completion for preview mode
                    Button {
                        completedDrills.insert(drill.id)
                        showDrillDetail = nil
                    } label: {
                        Label("Mark Complete (Preview)", systemImage: "checkmark.circle.fill")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(drill.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showDrillDetail = nil }
                        .foregroundStyle(drill.accentColor)
                }
            }
        }
    }
}
