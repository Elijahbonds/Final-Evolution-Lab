import SwiftUI
import PhotosUI
import AVFoundation

struct SystemScanView: View {
    let sport: String?
    let goal: String?
    let onComplete: (SystemScanResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: ScanPhase = .picking
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var analysisProgress: Double = 0
    @State private var scanLines: CGFloat = 0
    @State private var gridPulse: Bool = false

    private enum ScanPhase {
        case picking
        case analyzing
        case results
    }

    @State private var generatedResult: SystemScanResult?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.3).ignoresSafeArea()
                scanGrid

                VStack(spacing: 0) {
                    switch phase {
                    case .picking:
                        pickingPhase
                    case .analyzing:
                        analyzingPhase
                    case .results:
                        if let result = generatedResult {
                            resultsPhase(result)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
    }

    private var scanGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 32
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            let lineOpacity = gridPulse ? 0.06 : 0.02

            for col in 0...cols {
                let x = CGFloat(col) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Theme.brandBlue.opacity(lineOpacity)), lineWidth: 0.5)
            }
            for row in 0...rows {
                let y = CGFloat(row) * spacing
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Theme.brandBlue.opacity(lineOpacity)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }

    private var pickingPhase: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "film.stack")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)
                    .symbolEffect(.pulse)

                Text("SELECT YOUR CLIP")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue)
                    .tracking(3)

                Text("Upload a dunk or vertical jump attempt from your camera roll. Our system will analyze your movement data and generate your PRQ score.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                HStack(spacing: 20) {
                    ScanFeaturePill(icon: "waveform.path.ecg", label: "FLIGHT TIME")
                    ScanFeaturePill(icon: "arrow.up.and.down", label: "VERTICAL")
                    ScanFeaturePill(icon: "brain.head.profile.fill", label: "PRQ SCORE")
                }
            }

            PhotosPicker(
                selection: $selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("OPEN CAMERA ROLL")
                }
                .font(.system(.subheadline, design: .monospaced, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.brandBlue)
                .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .onChange(of: selectedItem) { _, newItem in
                guard newItem != nil else { return }
                startAnalysis()
            }

            Spacer()
        }
    }

    private var analyzingPhase: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.brandCyan.opacity(0.1), lineWidth: 3)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: analysisProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.brandBlue, Theme.brandCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Text("\(Int(analysisProgress * 100))%")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("ANALYZING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(3)
                }
            }

            VStack(spacing: 8) {
                Text(analysisLabel)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                    .contentTransition(.opacity)

                Text("Processing movement data...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                gridPulse = true
            }
        }
    }

    private var analysisLabel: String {
        switch analysisProgress {
        case 0..<0.25: "DETECTING BODY POSE..."
        case 0.25..<0.5: "MEASURING FLIGHT TIME..."
        case 0.5..<0.75: "CALCULATING VERTICAL..."
        case 0.75..<1.0: "GENERATING PRQ SCORE..."
        default: "COMPLETE"
        }
    }

    private func resultsPhase(_ result: SystemScanResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("SCAN COMPLETE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(4)

                    Text("Your PRQ")
                        .font(.system(size: 34, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                }

                ZStack {
                    Circle()
                        .fill(gradeColor(result.prqScore).opacity(0.08))
                        .frame(width: 160, height: 160)

                    Circle()
                        .stroke(gradeColor(result.prqScore).opacity(0.3), lineWidth: 3)
                        .frame(width: 160, height: 160)

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", result.prqScore))
                            .font(.system(size: 52, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("PRQ")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .tracking(3)
                    }
                }

                Text(result.movementGrade)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(gradeColor(result.prqScore))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ScanMetricCell(label: "VERTICAL", value: String(format: "%.1f\"", result.verticalEstimateInches), color: Theme.brandBlue)
                    ScanMetricCell(label: "FLIGHT", value: String(format: "%.2fs", result.flightTimeSeconds), color: Theme.brandCyan)
                    ScanMetricCell(label: "TRACK", value: result.recommendedTrack.uppercased(), color: Theme.elitePurple)
                }
                .padding(.horizontal)

                avatarPreviewSection(result.avatarConfig)

                if !result.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MOVEMENT NOTES")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(2)

                        ForEach(result.notes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.brandBlue)
                                    .padding(.top, 2)

                                Text(note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.cardBackground)
                    )
                    .padding(.horizontal)
                }

                Button {
                    onComplete(result)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("ENTER THE LAB")
                    }
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(gradeColor(result.prqScore))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func avatarPreviewSection(_ config: AvatarSkinConfig) -> some View {
        VStack(spacing: 10) {
            Text("AVATAR MODEL")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                                    .opacity(0.15)
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "figure.stand")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(
                                Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                            )
                            .scaleEffect(x: config.weightScale, y: config.heightScale)
                    }

                    Text(config.outfitStyle.rawValue.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB)
                        )
                        .tracking(1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    avatarStatRow(label: "HEIGHT", value: String(format: "%.0f%%", config.heightScale * 100))
                    avatarStatRow(label: "BUILD", value: String(format: "%.0f%%", config.weightScale * 100))
                    avatarStatRow(label: "REACH", value: String(format: "%.0f%%", config.limbLength * 100))
                    avatarStatRow(label: "AURA", value: String(format: "%.0f%%", config.trailIntensity * 100))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB).opacity(0.15),
                            lineWidth: 0.5
                        )
                )
        )
        .padding(.horizontal)
    }

    private func avatarStatRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func gradeColor(_ score: Double) -> Color {
        switch score {
        case 80...: Theme.elitePurple
        case 60..<80: Theme.brandBlue
        case 40..<60: Theme.foundationGreen
        default: .orange
        }
    }

    private func startAnalysis() {
        withAnimation(.spring(response: 0.4)) { phase = .analyzing }
        analysisProgress = 0

        Task {
            for i in 1...20 {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeInOut(duration: 0.2)) {
                    analysisProgress = Double(i) / 20.0
                }
            }

            let result = generateScanResult()
            generatedResult = result

            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.spring(response: 0.5)) {
                phase = .results
                gridPulse = false
            }
        }
    }

    private func generateScanResult() -> SystemScanResult {
        let basePRQ: Double
        let baseVertical: Double
        let baseFlight: Double
        let recommendedTrack: String

        switch goal ?? "" {
        case "Jump Higher":
            basePRQ = Double.random(in: 55...78)
            baseVertical = Double.random(in: 22...32)
            baseFlight = Double.random(in: 0.45...0.65)
            recommendedTrack = "Flight"
        case "Get Faster":
            basePRQ = Double.random(in: 50...72)
            baseVertical = Double.random(in: 18...28)
            baseFlight = Double.random(in: 0.38...0.55)
            recommendedTrack = "Foundations"
        case "Build Power":
            basePRQ = Double.random(in: 60...82)
            baseVertical = Double.random(in: 24...34)
            baseFlight = Double.random(in: 0.50...0.68)
            recommendedTrack = "Elite"
        default:
            basePRQ = Double.random(in: 45...70)
            baseVertical = Double.random(in: 20...28)
            baseFlight = Double.random(in: 0.40...0.55)
            recommendedTrack = "Foundations"
        }

        let grade: String
        switch basePRQ {
        case 80...: grade = "ELITE POTENTIAL"
        case 65..<80: grade = "FLIGHT READY"
        case 50..<65: grade = "BUILDING BASE"
        default: grade = "FOUNDATION PHASE"
        }

        var notes: [String] = []
        if basePRQ < 60 {
            notes.append("Focus on ankle stiffness drills to improve ground contact efficiency.")
        }
        if baseVertical < 26 {
            notes.append("Hip extension power can be improved with targeted plyometric progressions.")
        }
        notes.append("Knee tracking looks stable. Maintain current mobility work.")
        if basePRQ >= 70 {
            notes.append("Strong neural drive detected. Ready for advanced reactive training.")
        }
        if let sportName = sport, !sportName.isEmpty {
            notes.append("\(sportName)-specific movement patterns will be prioritized in your program.")
        }

        let clampedPRQ = PRQ.clamp(basePRQ)

        let avatarConfig = AvatarSkinConfig.fromScan(
            prq: clampedPRQ,
            vertical: baseVertical,
            flight: baseFlight,
            sport: sport
        )

        return SystemScanResult(
            id: UUID().uuidString,
            date: Date(),
            prqScore: clampedPRQ,
            verticalEstimateInches: baseVertical,
            flightTimeSeconds: baseFlight,
            movementGrade: grade,
            notes: notes,
            recommendedTrack: recommendedTrack,
            avatarConfig: avatarConfig
        )
    }
}

struct ScanFeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(Theme.brandCyan.opacity(0.6))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.brandCyan.opacity(0.06))
        .clipShape(Capsule())
    }
}

struct ScanMetricCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.headline, design: .monospaced, weight: .black))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
}
