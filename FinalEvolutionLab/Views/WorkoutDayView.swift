import SwiftUI

struct WorkoutDayView: View {
    let day: TrainingDay
    @Bindable var vm: TrainingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var activeExercise: TrainingExercise?
    @State private var timerTask: Task<Void, Never>?
    @State private var elapsedSeconds: Int = 0
    @State private var showFinishConfirm: Bool = false

    private var completionRate: Double {
        guard day.totalExerciseCount > 0 else { return 0 }
        return Double(vm.completedExerciseIds.count) / Double(day.totalExerciseCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dayHeader
                    timerCard
                    if !day.warmUp.isEmpty {
                        exerciseSection(title: "WARM UP", exercises: day.warmUp, accentColor: .orange)
                    }
                    exerciseSection(title: "MAIN WORK", exercises: day.mainWork, accentColor: Theme.difficultyColor(vm.currentTrack.difficulty))
                    progressBar
                    finishButton
                }
                .padding()
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Day \(day.dayNumber)\(day.variant)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                        .accessibilityHint("Closes workout and returns to training")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $activeExercise) { exercise in
                TrainingExerciseDetailView(
                    exercise: exercise,
                    level: vm.exerciseLevel(for: exercise.id),
                    isCompleted: vm.completedExerciseIds.contains(exercise.id),
                    onComplete: {
                        vm.completeExercise(exercise)
                    }
                )
            }
            .alert("Finish Workout?", isPresented: $showFinishConfirm) {
                Button("Finish", role: .destructive) {
                    vm.finishDay()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You completed \(vm.completedExerciseIds.count) of \(day.totalExerciseCount) exercises.")
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
        .onAppear {
            vm.startDay(day)
            startTimer()
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(day.category.rawValue.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(categoryColor.opacity(0.12))
                    .clipShape(Capsule())

                if day.isGated {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 9))
                        Text("GATED")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Text(day.title)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)

            Text("\(day.totalExerciseCount) exercises · \(day.warmUp.count) warm up + \(day.mainWork.count) main")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day \(day.dayNumber). \(day.title). \(day.totalExerciseCount) exercises.")
    }

    private var timerCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.brandBlue)

            Text(formatTime(elapsedSeconds))
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vm.completedExerciseIds.count)/\(day.totalExerciseCount)")
                    .font(.system(.headline, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)
                Text("COMPLETED")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.brandBlue.opacity(0.12), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout timer \(formatTime(elapsedSeconds)). \(vm.completedExerciseIds.count) of \(day.totalExerciseCount) completed.")
    }

    private func exerciseSection(title: String, exercises: [TrainingExercise], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(accentColor)
                .tracking(2)
                .accessibilityAddTraits(.isHeader)

            ForEach(exercises) { exercise in
                Button {
                    activeExercise = exercise
                } label: {
                    TrainingExerciseRow(
                        exercise: exercise,
                        isCompleted: vm.completedExerciseIds.contains(exercise.id),
                        level: vm.exerciseLevel(for: exercise.id),
                        accentColor: accentColor
                    )
                }
                .accessibilityLabel(exercise.name)
                .accessibilityHint(vm.completedExerciseIds.contains(exercise.id) ? "Completed. Tap to view details" : "Tap to open exercise and log sets")
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor, categoryColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * completionRate, height: 8)
                        .animation(.spring(response: 0.4), value: completionRate)
                }
            }
            .frame(height: 8)

            Text("\(Int(completionRate * 100))% complete")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress \(Int(completionRate * 100)) percent complete")
        .accessibilityValue("\(Int(completionRate * 100))%")
    }

    @ViewBuilder
    private var finishButton: some View {
        if !vm.completedExerciseIds.isEmpty {
            Button {
                showFinishConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 14, weight: .bold))
                    Text("FINISH WORKOUT")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(categoryColor)
                .clipShape(.rect(cornerRadius: 14))
            }
            .accessibilityLabel("Finish workout")
            .accessibilityHint("Marks workout complete and saves progress")
            .sensoryFeedback(.impact(flexibility: .soft), trigger: vm.completedExerciseIds.count)
        }
    }

    private var categoryColor: Color {
        switch day.category {
        case .strength: Theme.difficultyColor(vm.currentTrack.difficulty)
        case .recoveryIso, .recoveryPilates, .recovery: .cyan
        case .maxIntent: .orange
        case .jumpVariations: Theme.brandBlue
        case .movementEducation: Theme.neonGreen
        case .plyometrics: .orange
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                elapsedSeconds += 1
                vm.workoutTimer = elapsedSeconds
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

private struct TrainingExerciseRow: View {
    let exercise: TrainingExercise
    let isCompleted: Bool
    let level: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(isCompleted ? 0.05 : 0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(accentColor.opacity(0.2), lineWidth: 0.5)
                    )

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    ExerciseCharacterView(category: exercise.category, difficulty: .foundation, compact: true)
                        .frame(width: 44, height: 44)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(isCompleted ? Color.secondary : Color.white)
                        .lineLimit(1)

                    if exercise.hasLevels {
                        Text("L\(level)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }

                Text("\(exercise.sets)s × \(exercise.reps) · \(exercise.restSeconds)s rest")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !isCompleted {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isCompleted ? Color.green.opacity(0.2) : Theme.cardBorder, lineWidth: 0.5)
                )
        )
        .opacity(isCompleted ? 0.6 : 1)
    }
}
