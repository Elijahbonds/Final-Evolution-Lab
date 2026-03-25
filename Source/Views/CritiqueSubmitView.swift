import SwiftUI

struct CritiqueSubmitView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedExercise: String = ""
    @State private var feedbackText: String = ""
    @State private var overallGrade: String = "DEVELOPING"
    @State private var focusAreas: Set<String> = []
    @State private var drawingPaths: [DrawingPath] = []
    @State private var currentPath: [CGPoint] = []
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 3
    @State private var isDrawing: Bool = false
    @State private var showConfirmation: Bool = false

    private let exerciseOptions = [
        "Scaled Pogos", "Lateral Leaps", "Box Jumps",
        "Depth Drops", "Dunk Approach", "Sprint Mechanics",
        "Ankle Dorsiflexion", "Hip Extension", "Knee Tracking"
    ]

    private let gradeOptions = ["ELITE", "PRIMED", "DEVELOPING", "FOUNDATION"]

    private let focusAreaOptions = [
        "Ankle Stiffness", "Knee Valgus", "Hip Extension",
        "Ground Contact", "Flight Time", "Load Phase",
        "Arm Swing", "Core Stability", "Landing Mechanics"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    exerciseSelector
                    telestrationCanvas
                    feedbackSection
                    gradingSection
                    focusAreaSelector
                    submitButton
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Coach Critique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
        .overlay {
            if showConfirmation {
                confirmationOverlay
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)

                Text("TELESTRATOR CRITIQUE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
            }

            Text("Draw annotations on the movement frame and provide expert feedback")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exerciseSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXERCISE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(exerciseOptions, id: \.self) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            Text(exercise.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(selectedExercise == exercise ? .black : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedExercise == exercise ? Theme.brandCyan : Theme.cardBackground)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private var telestrationCanvas: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TELESTRATOR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(2)

                Spacer()

                Button {
                    if !drawingPaths.isEmpty {
                        drawingPaths.removeLast()
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }

                Button {
                    drawingPaths.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)

                skeletonPlaceholder

                Canvas { context, _ in
                    for path in drawingPaths {
                        var bezierPath = Path()
                        guard let first = path.points.first else { continue }
                        bezierPath.move(to: first)
                        for point in path.points.dropFirst() {
                            bezierPath.addLine(to: point)
                        }
                        context.stroke(
                            bezierPath,
                            with: .color(path.color),
                            style: StrokeStyle(lineWidth: path.lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }

                    if !currentPath.isEmpty {
                        var bezierPath = Path()
                        bezierPath.move(to: currentPath[0])
                        for point in currentPath.dropFirst() {
                            bezierPath.addLine(to: point)
                        }
                        context.stroke(
                            bezierPath,
                            with: .color(selectedColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentPath.append(value.location)
                        }
                        .onEnded { _ in
                            if !currentPath.isEmpty {
                                drawingPaths.append(DrawingPath(
                                    points: currentPath,
                                    color: selectedColor,
                                    lineWidth: lineWidth
                                ))
                                currentPath = []
                            }
                        }
                )
            }
            .frame(height: 280)
            .clipShape(.rect(cornerRadius: 16))

            colorPicker
        }
    }

    private var skeletonPlaceholder: some View {
        GeometryReader { geo in
            let cx = geo.size.width * 0.5
            let topY = geo.size.height * 0.12

            ZStack {
                Circle()
                    .fill(Theme.brandCyan.opacity(0.15))
                    .frame(width: 24, height: 24)
                    .position(x: cx, y: topY)

                Path { path in
                    path.move(to: CGPoint(x: cx, y: topY + 12))
                    path.addLine(to: CGPoint(x: cx, y: topY + 80))
                    path.move(to: CGPoint(x: cx, y: topY + 30))
                    path.addLine(to: CGPoint(x: cx - 35, y: topY + 55))
                    path.move(to: CGPoint(x: cx, y: topY + 30))
                    path.addLine(to: CGPoint(x: cx + 35, y: topY + 55))
                    path.move(to: CGPoint(x: cx, y: topY + 80))
                    path.addLine(to: CGPoint(x: cx - 25, y: topY + 130))
                    path.move(to: CGPoint(x: cx, y: topY + 80))
                    path.addLine(to: CGPoint(x: cx + 25, y: topY + 130))
                }
                .stroke(Theme.brandCyan.opacity(0.2), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                ForEach(JointType.allCases, id: \.rawValue) { joint in
                    let pos = jointPosition(joint, centerX: cx, topY: topY)
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .position(x: pos.x, y: pos.y)
                }
            }
        }
    }

    private func jointPosition(_ joint: JointType, centerX: CGFloat, topY: CGFloat) -> CGPoint {
        switch joint {
        case .hip: CGPoint(x: centerX, y: topY + 80)
        case .knee: CGPoint(x: centerX, y: topY + 105)
        case .ankle: CGPoint(x: centerX, y: topY + 130)
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach([Color.red, Color.yellow, Theme.brandCyan, .green, .white], id: \.self) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: selectedColor == color ? 2 : 0)
                        )
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text("SIZE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Slider(value: $lineWidth, in: 1...8)
                    .tint(Theme.brandCyan)
                    .frame(width: 80)
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COACHING NOTES")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            TextEditor(text: $feedbackText)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.cardBorder, lineWidth: 0.5)
                        )
                )
        }
    }

    private var gradingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOVEMENT GRADE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            HStack(spacing: 8) {
                ForEach(gradeOptions, id: \.self) { grade in
                    Button {
                        overallGrade = grade
                    } label: {
                        Text(grade)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(overallGrade == grade ? .black : gradeColor(grade))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(overallGrade == grade ? gradeColor(grade) : gradeColor(grade).opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var focusAreaSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FOCUS AREAS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(focusAreaOptions, id: \.self) { area in
                    Button {
                        if focusAreas.contains(area) {
                            focusAreas.remove(area)
                        } else {
                            focusAreas.insert(area)
                        }
                    } label: {
                        Text(area.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(focusAreas.contains(area) ? .black : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(focusAreas.contains(area) ? Theme.brandCyan : Theme.cardBackground)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var submitButton: some View {
        Button {
            submitCritique()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                Text("SUBMIT CRITIQUE")
            }
            .font(.system(.subheadline, design: .monospaced, weight: .black))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? Theme.brandCyan : Color.gray.opacity(0.3))
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(!canSubmit)
        .padding(.bottom, 16)
    }

    private var canSubmit: Bool {
        !selectedExercise.isEmpty && !feedbackText.isEmpty && feedbackText.count >= 10
    }

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.brandCyan)

                Text("CRITIQUE SUBMITTED")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("150 Shards held in escrow — released when the athlete reviews your feedback")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Theme.brandCyan)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
        .transition(.opacity)
    }

    private func submitCritique() {
        let critiqueId = UUID().uuidString
        viewModel.coachEconomy.completeCritique(shards: 150, critiqueId: critiqueId)
        SaveSystem.saveCoachEconomy(viewModel.coachEconomy)

        withAnimation(.spring(response: 0.4)) {
            showConfirmation = true
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "ELITE": Theme.elitePurple
        case "PRIMED": Theme.brandBlue
        case "DEVELOPING": .orange
        default: Theme.foundationGreen
        }
    }
}

struct DrawingPath: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
}
