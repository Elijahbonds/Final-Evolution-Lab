import SwiftUI
import AVKit
import PhotosUI

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
    @State private var requestedRealClip = false
    @State private var selectedRealClip: PhotosPickerItem?
    @State private var clipAttachStatus: String?

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
                    Button("Close") { closeDemo() }
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
            demoEngine.loadDemo(for: exercise.id, movementDatabase: viewModel.movementDatabase)
            requestedRealClip = viewModel.movementDatabase.requestedRealClipExerciseIds.contains(exercise.id)
        }
        .onChange(of: selectedRealClip) { _, newValue in
            guard let newValue else { return }
            attachSelectedRealClip(newValue)
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
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
                if demoEngine.currentMode == .coach {
                    if case .ready(let payload) = demoEngine.loadState {
                        switch payload {
                        case .generatedAnimation:
                            AvatarDemoView(
                                exercise: exercise,
                                cloneProfile: viewModel.cloneProfile,
                                badgeText: "DIGITAL CLONE • \(viewModel.cloneProfile.displayName.uppercased())"
                            )
                            .transition(.opacity)
                        case .localClip(_, let url):
                            VideoPlayerView(url: url)
                                .transition(.opacity)
                        case .referenceOnly:
                            AvatarDemoView(
                                exercise: exercise,
                                cloneProfile: viewModel.cloneProfile,
                                badgeText: "REFERENCE MODE • CLONE PREVIEW"
                            )
                            .transition(.opacity)
                        }
                    } else {
                        AvatarDemoView(
                            exercise: exercise,
                            cloneProfile: viewModel.cloneProfile,
                            badgeText: "CLONE PREVIEW"
                        )
                        .transition(.opacity)
                    }
                } else {
                    AvatarDemoView(
                        exercise: exercise,
                        cloneProfile: viewModel.cloneProfile,
                        badgeText: "AI AVATAR MODE"
                    )
                    .transition(.opacity)
                }
            }
            .clipShape(.rect(cornerRadius: 24))

            if demoEngine.currentMode == .coach {
                if case .loading = demoEngine.loadState {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.brandBlue)
                        Text("PREPARING DIGITAL CLONE DEMO...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandBlue.opacity(0.6))
                            .tracking(2)
                    }
                } else if demoEngine.isReferenceOnly || demoEngine.shouldShowRequestRealClip {
                    VStack(spacing: 10) {
                        Text(demoEngine.sourceBadgeText)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandBlue)
                        Text("Reference assets are internal only. No external links are opened in-app.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
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
                    if mode == .coach && !demoEngine.isCoachDemoAvailable && !demoEngine.isReferenceOnly {
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
                            : (mode == .coach && !demoEngine.isCoachDemoAvailable && !demoEngine.isReferenceOnly ? Color.white.opacity(0.15) : Color.white.opacity(0.4))
                    )
                }
                .disabled(mode == .coach && !demoEngine.isCoachDemoAvailable && !demoEngine.isReferenceOnly)
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

            HStack(spacing: 10) {
                InfoPill(label: "DEMO", value: demoEngine.sourceBadgeText)
                InfoPill(label: "QUALITY", value: demoEngine.qualityPercentText)
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
            if demoEngine.shouldShowRequestRealClip {
                Button {
                    requestedRealClip = viewModel.requestRealExerciseClip(exerciseId: exercise.id)
                } label: {
                    Text(requestedRealClip ? "REAL CLIP REQUESTED" : "REQUEST REAL CLIP")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(requestedRealClip ? Theme.foundationGreen : Color.white.opacity(0.08))
                        .foregroundStyle(requestedRealClip ? .black : .white)
                        .clipShape(.rect(cornerRadius: 14))
                }

                if requestedRealClip {
                    PhotosPicker(
                        selection: $selectedRealClip,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Text("ATTACH REAL CLIP")
                            .font(.system(.subheadline, design: .monospaced, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.06))
                            .foregroundStyle(.white)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    if let clipAttachStatus {
                        Text(clipAttachStatus)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

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

    private func closeDemo() {
        timerTask?.cancel()
        timerTask = nil
        dismiss()
    }

    private func attachSelectedRealClip(_ item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    clipAttachStatus = "CLIP ATTACH FAILED"
                }
                return
            }

            let filename = "real_clip_\(exercise.id)_\(UUID().uuidString).mov"
            guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                await MainActor.run {
                    clipAttachStatus = "CLIP STORAGE UNAVAILABLE"
                }
                return
            }

            let targetURL = documents.appendingPathComponent(filename)
            do {
                try data.write(to: targetURL, options: .atomic)
                let attached = viewModel.attachLocalRealExerciseClip(
                    exerciseId: exercise.id,
                    localFilename: filename
                )
                demoEngine.loadDemo(for: exercise.id, movementDatabase: viewModel.movementDatabase)
                await MainActor.run {
                    clipAttachStatus = attached ? "REAL CLIP ATTACHED" : "CLIP ATTACH REJECTED"
                }
            } catch {
                await MainActor.run {
                    clipAttachStatus = "CLIP ATTACH FAILED"
                }
            }
        }
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
