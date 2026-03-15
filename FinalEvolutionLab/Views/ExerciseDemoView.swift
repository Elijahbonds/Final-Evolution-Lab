import SwiftUI
import AVKit

struct ExerciseDemoView: View {
    let exercise: Exercise
    let viewModel: LabViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isComplete = false
    @State private var currentSet = 1
    @State private var restTimer: Int = 0
    @State private var isResting = false
    @State private var timerTask: Task<Void, Never>?
    @State private var demoEngine = DemoEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    demoVisual
                    modeToggle
                    exerciseInfo
                    setTracker
                    actionButtons
                }
                .padding()
            }
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
            .sensoryFeedback(.success, trigger: isComplete)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
        .onAppear {
            demoEngine.currentMode = .avatar
            demoEngine.loadVideo(for: exercise.id)
        }
    }

    private var demoVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.difficultyColor(exercise.difficulty).opacity(0.15),
                            Theme.cardBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 280)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Theme.difficultyColor(exercise.difficulty).opacity(0.2), lineWidth: 1)
                )

            Group {
                if demoEngine.currentMode == .coach && demoEngine.isVideoAvailable, case .ready(let url) = demoEngine.videoLoadState {
                    VideoPlayerView(url: url)
                        .transition(.opacity)
                } else {
                    AvatarDemoView(exercise: exercise)
                        .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: 24))

            if demoEngine.currentMode == .coach && !demoEngine.isVideoAvailable {
                if case .loading = demoEngine.videoLoadState {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.brandBlue)
                        Text("LOADING COACH VIDEO...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandBlue.opacity(0.6))
                            .tracking(2)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "play.slash.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.brandBlue.opacity(0.5))
                        Text("VIDEO UNAVAILABLE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        Text("Showing avatar demo")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            NeuralScanOverlay(isActive: demoEngine.isTransitioning)
                .clipShape(.rect(cornerRadius: 24))
        }
        .frame(height: 280)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(DemoMode.allCases, id: \.self) { mode in
                Button {
                    guard demoEngine.currentMode != mode else { return }
                    if mode == .coach && !demoEngine.isVideoAvailable {
                        return
                    }
                    demoEngine.toggleMode()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode == .coach ? "play.rectangle.fill" : "figure.mixed.cardio")
                            .font(.system(size: 12, weight: .bold))
                        Text(mode == .coach ? "COACH" : "AVATAR")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        demoEngine.currentMode == mode
                            ? Theme.brandBlue.opacity(0.15)
                            : Color.white.opacity(0.03)
                    )
                    .foregroundStyle(
                        demoEngine.currentMode == mode
                            ? Theme.brandBlue
                            : (mode == .coach && !demoEngine.isVideoAvailable ? Color.white.opacity(0.15) : Color.white.opacity(0.4))
                    )
                }
                .disabled(mode == .coach && !demoEngine.isVideoAvailable)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.brandBlue.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                DifficultyBadge(difficulty: exercise.difficulty)
                CategoryBadge(category: exercise.category)
            }

            Text(exercise.demoDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                InfoPill(label: "SETS", value: "\(exercise.sets)")
                InfoPill(label: "REPS", value: exercise.reps)
                InfoPill(label: "REST", value: "\(exercise.restSeconds)s")
            }

            if !exercise.muscleGroups.isEmpty {
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
        }
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
                        .fill(set < currentSet ? Theme.brandBlue :
                              set == currentSet && !isComplete ? Theme.brandBlue.opacity(0.3) :
                              isComplete ? Theme.brandBlue :
                              Color.white.opacity(0.06))
                        .frame(height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(set == currentSet && !isComplete ?
                                        Theme.brandBlue.opacity(0.5) : .clear, lineWidth: 1)
                        )
                }
            }

            if isResting {
                VStack(spacing: 4) {
                    Text("REST")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandBlue)
                    Text("\(restTimer)s")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isComplete {
                Button {
                    viewModel.completeExercise(exercise)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("EXERCISE COMPLETE")
                    }
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.brandBlue)
                    .foregroundStyle(.black)
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
                        .background(Theme.difficultyColor(exercise.difficulty))
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
    }

    private func completeSet() {
        if currentSet >= exercise.sets {
            withAnimation(.spring) { isComplete = true }
        } else {
            currentSet += 1
            startRest()
        }
    }

    private func startRest() {
        restTimer = exercise.restSeconds
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

struct DifficultyBadge: View {
    let difficulty: Exercise.Difficulty

    var body: some View {
        Text(difficulty.rawValue.uppercased())
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.difficultyColor(difficulty).opacity(0.15))
            .foregroundStyle(Theme.difficultyColor(difficulty))
            .clipShape(Capsule())
    }
}

struct CategoryBadge: View {
    let category: Exercise.ExerciseCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
                .font(.system(size: 10))
            Text(category.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .foregroundStyle(.secondary)
        .clipShape(Capsule())
    }
}

struct InfoPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
    }
}
