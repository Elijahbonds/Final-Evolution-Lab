import SwiftUI

struct TrainingHubView: View {
    let labViewModel: LabViewModel
    @State private var trainingVM: TrainingViewModel?
    @State private var selectedDay: TrainingDay?
    @State private var appeared: Bool = false

    var body: some View {
        Group {
            if let vm = trainingVM {
                TrainingHubContent(vm: vm, labViewModel: labViewModel, selectedDay: $selectedDay, appeared: $appeared)
            } else {
                ProgressView()
                    .tint(Theme.brandBlue)
            }
        }
        .onAppear {
            if trainingVM == nil {
                trainingVM = TrainingViewModel(labViewModel: labViewModel)
            }
            withAnimation(.spring(response: 0.5)) { appeared = true }
        }
    }
}

private struct TrainingHubContent: View {
    @Bindable var vm: TrainingViewModel
    let labViewModel: LabViewModel
    @Binding var selectedDay: TrainingDay?
    @Binding var appeared: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                trackSelector
                progressCard
                recoveryGateCard
                nextWorkoutCard
                scheduleSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .sheet(item: $selectedDay) { day in
            WorkoutDayView(day: day, vm: vm)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("3-TRACK SYSTEM")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.neonGreen)
                .tracking(4)

            Text("Training")
                .font(.system(size: 52, weight: .black))
                .italic()
                .foregroundStyle(.white)

            Text("Foundations → Flight → Elite")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var trackSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrainingTrack.allCases) { track in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        vm.switchTrack(to: track)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: track.icon)
                            .font(.system(size: 16, weight: .bold))

                        Text(track.rawValue.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        vm.currentTrack == track
                            ? Theme.difficultyColor(track.difficulty).opacity(0.15)
                            : Color.white.opacity(0.03)
                    )
                    .foregroundStyle(
                        vm.currentTrack == track
                            ? Theme.difficultyColor(track.difficulty)
                            : .secondary
                    )
                }
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.difficultyColor(vm.currentTrack.difficulty).opacity(0.15), lineWidth: 1)
        )
    }

    private var progressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.currentTrack.rawValue.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.difficultyColor(vm.currentTrack.difficulty))
                        .tracking(2)

                    Text(vm.currentTrack.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 6)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: vm.overallProgress)
                        .stroke(
                            Theme.difficultyColor(vm.currentTrack.difficulty),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(vm.overallProgress * 100))%")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 12) {
                progressStat(icon: "checkmark.circle.fill", value: "\(vm.completedDays.count)", label: "DONE")
                progressStat(icon: "list.bullet", value: "\(vm.availableDays.count)", label: "TOTAL")
                progressStat(icon: "diamond.fill", value: "\(vm.progress.totalShardsEarned)", label: "SHARDS")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.difficultyColor(vm.currentTrack.difficulty).opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func progressStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.difficultyColor(vm.currentTrack.difficulty))

            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    @ViewBuilder
    private var recoveryGateCard: some View {
        if !vm.progress.recoveryGateCleared {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("RECOVERY GATE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(2)

                    Text("Complete a Recovery session to unlock the next Max Intent day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private var nextWorkoutCard: some View {
        if let next = vm.nextAvailableDay {
            Button {
                selectedDay = next
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.neonGreen.opacity(0.12))
                            .frame(width: 56, height: 56)

                        Image(systemName: next.category.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.neonGreen)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT UP")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.neonGreen)
                            .tracking(2)

                        Text("Day \(next.dayNumber)\(next.variant): \(next.title)")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(next.totalExerciseCount) exercises · \(next.category.rawValue)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.neonGreen)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Theme.neonGreen.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WEEKLY SCHEDULE")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            ForEach(Array(vm.availableDays.enumerated()), id: \.element.id) { index, day in
                Button {
                    if vm.canAccessDay(day) && !vm.dayIsCompleted(day) {
                        selectedDay = day
                    }
                } label: {
                    TrainingDayRow(
                        day: day,
                        isCompleted: vm.dayIsCompleted(day),
                        isLocked: !vm.canAccessDay(day),
                        trackDifficulty: vm.currentTrack.difficulty
                    )
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.spring(response: 0.4).delay(Double(index) * 0.04), value: appeared)
                }
                .disabled(vm.dayIsCompleted(day) || !vm.canAccessDay(day))
            }
        }
    }
}

private struct TrainingDayRow: View {
    let day: TrainingDay
    let isCompleted: Bool
    let isLocked: Bool
    let trackDifficulty: Exercise.Difficulty

    private var accentColor: Color {
        if isCompleted { return .green }
        if isLocked { return .gray }
        if day.category.isRecovery { return .cyan }
        if day.category == .maxIntent { return .orange }
        return Theme.difficultyColor(trackDifficulty)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.gray)
                } else {
                    Image(systemName: day.category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Day \(day.dayNumber)\(day.variant)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)

                    if day.isGated {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange.opacity(0.7))
                    }
                }

                Text(day.title)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(isLocked ? .secondary : .white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(day.category.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.7))

                Text("\(day.totalExerciseCount) ex")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if !isCompleted && !isLocked {
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
        .opacity(isLocked ? 0.5 : 1)
    }
}
