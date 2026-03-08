import SwiftUI

struct TrainingExerciseDetailView: View {
    let exercise: TrainingExercise
    let level: Int
    let isCompleted: Bool
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentSet: Int = 1
    @State private var isResting: Bool = false
    @State private var restTimer: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var exerciseDone: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    exerciseHeader
                    levelIndicator
                    cuesCard
                    muscleGroupTags
                    setTracker
                    actionButtons
                }
                .padding()
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: currentSet)
            .sensoryFeedback(.success, trigger: exerciseDone)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private var exerciseHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.2), Theme.cardBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(accentColor.opacity(0.2), lineWidth: 1)
                    )

                VStack(spacing: 12) {
                    Image(systemName: exercise.category.systemImage)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(accentColor)

                    HStack(spacing: 8) {
                        Text(exercise.category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())

                        if isCompleted {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                Text("DONE")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                statPill(label: "SETS", value: "\(exercise.sets)")
                statPill(label: "REPS", value: exercise.reps)
                statPill(label: "REST", value: "\(exercise.restSeconds)s")
            }
        }
    }

    @ViewBuilder
    private var levelIndicator: some View {
        if exercise.hasLevels {
            VStack(spacing: 10) {
                Text("PROGRESSION LEVEL")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { lvl in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(lvl <= level ? accentColor.opacity(0.2) : Color.white.opacity(0.04))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(lvl == level ? accentColor : Color.clear, lineWidth: 2)
                                    )

                                Text("\(lvl)")
                                    .font(.system(.headline, design: .monospaced, weight: .black))
                                    .foregroundStyle(lvl <= level ? accentColor : Color.secondary.opacity(0.7))
                            }

                            Text("Level \(lvl)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(lvl == level ? accentColor : Color.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
    }

    private var cuesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)

                Text("COACHING CUES")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }

            Text(exercise.cues)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.brandBlue.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private var muscleGroupTags: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(exercise.muscleGroups, id: \.self) { muscle in
                    Text(muscle.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var setTracker: some View {
        VStack(spacing: 12) {
            Text("SET PROGRESS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            HStack(spacing: 8) {
                ForEach(1...exercise.sets, id: \.self) { set in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            set < currentSet ? accentColor :
                            set == currentSet && !exerciseDone ? accentColor.opacity(0.3) :
                            exerciseDone ? accentColor :
                            Color.white.opacity(0.06)
                        )
                        .frame(height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(set == currentSet && !exerciseDone ? accentColor.opacity(0.5) : .clear, lineWidth: 1)
                        )
                }
            }

            if isResting {
                VStack(spacing: 4) {
                    Text("REST")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text("\(restTimer)s")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isCompleted || exerciseDone {
                Button {
                    if !isCompleted {
                        onComplete()
                    }
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(isCompleted ? "ALREADY COMPLETED" : "EXERCISE COMPLETE")
                    }
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isCompleted ? Color.green.opacity(0.3) : accentColor)
                    .foregroundStyle(isCompleted ? .green : .black)
                    .clipShape(.rect(cornerRadius: 14))
                }
            } else if isResting {
                Button {
                    skipRest()
                } label: {
                    Text("SKIP REST")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
            } else {
                Button {
                    completeSet()
                } label: {
                    Text("COMPLETE SET \(currentSet)")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
    }

    private var accentColor: Color {
        switch exercise.category {
        case .plyometric: Theme.brandBlue
        case .strength: Theme.neonGreen
        case .mobility: .cyan
        case .agility: .orange
        case .recovery: .purple
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.secondary.opacity(0.7))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func completeSet() {
        if currentSet >= exercise.sets {
            withAnimation(.spring) { exerciseDone = true }
        } else {
            currentSet += 1
            startRest()
        }
    }

    private func startRest() {
        restTimer = exercise.restSeconds
        guard restTimer > 0 else { return }
        withAnimation(.spring) { isResting = true }
        timerTask?.cancel()
        timerTask = Task {
            while restTimer > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                restTimer -= 1
            }
            withAnimation(.spring) { isResting = false }
        }
    }

    private func skipRest() {
        timerTask?.cancel()
        withAnimation(.spring) { isResting = false }
    }
}
