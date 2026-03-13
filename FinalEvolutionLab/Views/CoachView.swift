import SwiftUI

struct CoachView: View {
    let viewModel: LabViewModel

    @State private var selectedDifficulty: Exercise.Difficulty = .foundation
    @State private var selectedExercise: Exercise?
    @State private var showCritiqueSubmit: Bool = false
    @State private var showCritiqueRequest: Bool = false

    private var filteredExercises: [Exercise] {
        viewModel.allExercises.filter { $0.difficulty == selectedDifficulty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                athleteCritiqueCard
                coachEconomyCard
                difficultyPicker
                exercisesList
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDemoView(exercise: exercise, viewModel: viewModel)
        }
        .sheet(isPresented: $showCritiqueSubmit) {
            CritiqueSubmitView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCritiqueRequest) {
            CritiqueRequestView(viewModel: viewModel)
        }
    }

    private var athleteCritiqueCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REQUEST A CRITIQUE")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandBlue)
                        .tracking(2)

                    Text("Spend credits for expert movement analysis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showCritiqueRequest = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 10))
                        Text("\(LabViewModel.critiqueCostCredits)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.brandBlue)
                    .clipShape(Capsule())
                }
            }

            if !viewModel.critiqueRequests.isEmpty {
                let completed = viewModel.critiqueRequests.filter { $0.status == .completed }.count
                let pending = viewModel.critiqueRequests.filter { $0.status == .pending }.count

                HStack(spacing: 12) {
                    if completed > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("\(completed) ready to review")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }
                    if pending > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.orange)
                                .frame(width: 6, height: 6)
                            Text("\(pending) pending")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandBlue.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EXERCISE LIBRARY")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)

            Text("Coach")
                .font(.system(size: 52, weight: .black))
                .italic()
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    private var coachEconomyCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CRITIQUE ECONOMY")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)

                    Text("Earn credits by reviewing athlete scans")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showCritiqueSubmit = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 10, weight: .bold))
                        Text("CRITIQUE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.brandCyan)
                    .clipShape(Capsule())
                }
            }

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(viewModel.coachEconomy.critiquesCompleted)")
                        .font(.system(.headline, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                    Text("COMPLETED")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.brandCyan)
                        Text("\(viewModel.coachEconomy.pendingCredits)")
                            .font(.system(.headline, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Text("PENDING")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.foundationGreen)
                        Text("\(viewModel.coachEconomy.totalCreditsEarned)")
                            .font(.system(.headline, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Text("EARNED")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
            }

            if viewModel.coachEconomy.clearedCredits > 0 {
                Button {
                    _ = viewModel.withdrawCreatorCredits()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                        Text("CLAIM \(viewModel.coachEconomy.clearedCredits) CREDITS")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.foundationGreen)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(Exercise.Difficulty.allCases, id: \.self) { diff in
                Button {
                    withAnimation(.snappy) { selectedDifficulty = diff }
                } label: {
                    Text(diff.rawValue.uppercased())
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedDifficulty == diff ?
                                      Theme.difficultyColor(diff).opacity(0.2) :
                                      Color.white.opacity(0.04))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedDifficulty == diff ?
                                        Theme.difficultyColor(diff).opacity(0.5) :
                                        Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(selectedDifficulty == diff ?
                                        Theme.difficultyColor(diff) : .secondary)
                }
            }
        }
    }

    private var exercisesList: some View {
        VStack(spacing: 10) {
            ForEach(filteredExercises) { exercise in
                Button {
                    selectedExercise = exercise
                } label: {
                    ExerciseRow(exercise: exercise, isCompleted: viewModel.completedExerciseIds.contains(exercise.id))
                }
            }
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.difficultyColor(exercise.difficulty).opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: exercise.category.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.difficultyColor(exercise.difficulty))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.white)

                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Text("\(exercise.sets) sets × \(exercise.reps)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(exercise.category.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.difficultyColor(exercise.difficulty).opacity(0.7))

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCompleted ? Color.green.opacity(0.2) : Theme.cardBorder, lineWidth: 0.5)
                )
        )
    }
}
