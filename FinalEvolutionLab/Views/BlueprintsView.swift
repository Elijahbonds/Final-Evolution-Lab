import SwiftUI

struct BlueprintsView: View {
    let viewModel: LabViewModel

    @State private var selectedTrack: CurriculumTrack?
    @State private var appeared = false
    @State private var selectedTab: BlueprintTab = .tracks

    private enum BlueprintTab: String, CaseIterable {
        case tracks = "Tracks"
        case library = "Library"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                tabPicker

                switch selectedTab {
                case .tracks:
                    tracksSection
                    progressOverview
                case .library:
                    blueprintLibrarySection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .onAppear {
            withAnimation { appeared = true }
        }
        .sheet(item: $selectedTrack) { track in
            TrackDetailView(track: track, viewModel: viewModel)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BONDS BOUNCE")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15))
                .tracking(4)

            Text("Blueprints")
                .font(.system(size: 52, weight: .black))
                .italic()
                .foregroundStyle(.white)

            Text("Master the vertical jump architecture")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(BlueprintTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? Theme.brandBlue.opacity(0.15) : Color.white.opacity(0.03))
                        .foregroundStyle(selectedTab == tab ? Theme.brandBlue : .secondary)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.brandBlue.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var tracksSection: some View {
        VStack(spacing: 16) {
            ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                Button {
                    selectedTrack = track
                } label: {
                    TrackCard(track: track)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(Double(index) * 0.1), value: appeared)
                }
            }
        }
    }

    private var blueprintLibrarySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("BLUEPRINT LIBRARY")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15))
                        .tracking(2)

                    Spacer()

                    Link(destination: SafeURL.make("https://youtube.com/@FinalEvolutionFitness")) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("FULL LIBRARY")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.15))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.95, green: 0.49, blue: 0.15).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Text("Video guides with timestamps and coaching cues for every phase of the Bonds Bounce system.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(BlueprintLibrary.blueprints.enumerated()), id: \.element.id) { index, bp in
                Link(destination: bp.url) {
                    BlueprintCard(blueprint: bp)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                        .animation(.spring(response: 0.5).delay(Double(index) * 0.08), value: appeared)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("PHASE PROGRESSION")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                ForEach(BlueprintLibrary.phases, id: \.name) { phase in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(phase.color.opacity(0.12))
                                .frame(width: 44, height: 44)

                            Text("\(phase.number)")
                                .font(.system(.headline, design: .monospaced, weight: .black))
                                .foregroundStyle(phase.color)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(phase.name.uppercased())
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white)

                            Text(phase.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(phase.color.opacity(0.08), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
    }

    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR PROGRESS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            HStack(spacing: 12) {
                ProgressStat(label: "WORKOUTS", value: "\(viewModel.profile.totalWorkouts)", icon: "figure.run")
                ProgressStat(label: "STREAK", value: "\(viewModel.profile.streakDays)d", icon: "flame.fill")
                ProgressStat(label: "WEEKLY", value: "\(viewModel.weeklyShards)", icon: "diamond.fill")
            }
        }
    }
}

struct BlueprintCard: View {
    let blueprint: BlueprintLibrary.Blueprint

    private let accentOrange = Color(red: 0.95, green: 0.49, blue: 0.15)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentOrange.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: blueprint.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accentOrange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(blueprint.title.uppercased())
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(blueprint.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(blueprint.category.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentOrange.opacity(0.7))
                        .tracking(1)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentOrange.opacity(0.5))
                }
            }

            if !blueprint.phases.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(blueprint.phases, id: \.self) { phase in
                            Text(phase.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.04))
                                .foregroundStyle(.tertiary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentOrange.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

struct TrackCard: View {
    let track: CurriculumTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.difficulty.rawValue.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.difficultyColor(track.difficulty))
                        .tracking(2)

                    Text(track.name)
                        .font(.system(.title2, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.difficultyColor(track.difficulty).opacity(0.1))
                        .frame(width: 50, height: 50)

                    Text("\(track.weekDuration)")
                        .font(.system(.title3, design: .monospaced, weight: .black))
                        .foregroundStyle(Theme.difficultyColor(track.difficulty))
                }
            }

            Text(track.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label("\(track.totalExercises) exercises", systemImage: "list.bullet")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()

                Label("\(track.weekDuration) weeks", systemImage: "calendar")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Theme.difficultyColor(track.difficulty), Theme.difficultyColor(track.difficulty).opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .clipShape(Capsule())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.difficultyColor(track.difficulty).opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct TrackDetailView: View {
    let track: CurriculumTrack
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise: Exercise?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        DifficultyBadge(difficulty: track.difficulty)
                        Text(track.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Label("\(track.totalExercises) exercises", systemImage: "list.bullet")
                            Label("\(track.weekDuration) weeks", systemImage: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }

                    ForEach(track.exercises) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            ExerciseRow(exercise: exercise, isCompleted: viewModel.completedExerciseIds.contains(exercise.id))
                        }
                    }

                    if !viewModel.completedExerciseIds.isEmpty {
                        Button {
                            viewModel.finishWorkout(for: track)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "flag.checkered")
                                Text("FINISH WORKOUT")
                            }
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.brandBlue)
                            .foregroundStyle(.black)
                            .clipShape(.rect(cornerRadius: 14))
                        }
                    }
                }
                .padding()
            }
            .background(Theme.deepBlack)
            .navigationTitle(track.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDemoView(exercise: exercise, viewModel: viewModel)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
    }
}

struct ProgressStat: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.brandBlue)

            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
    }
}
