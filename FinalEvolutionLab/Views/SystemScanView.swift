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

                if let screening = result.movementScreening {
                    movementScreenSummarySection(screening)
                    dysfunctionSection(screening)
                    prescriptionSection(screening)
                }

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

    private func movementScreenSummarySection(_ screening: MovementScreeningReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MOVEMENT SCREENS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            HStack(spacing: 8) {
                ForEach(screening.screenResults) { screen in
                    VStack(spacing: 4) {
                        Text(screen.kind.rawValue)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text("\(Int(screen.totalScore))/\(Int(screen.maxScore))")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(screen.riskBand.rawValue.uppercased())
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(screen.riskBand == .low ? Theme.foundationGreen : (screen.riskBand == .moderate ? .orange : .red))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 10))
                }
            }

            Text(
                String(
                    format: "Stress Test: %.1fs • %.0f fps • %d reps • fatigue %.0f%%",
                    screening.stressTest.clipDurationSeconds,
                    screening.stressTest.frameRate,
                    screening.stressTest.estimatedRepCount,
                    screening.stressTest.fatigueIndex * 100
                )
            )
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
        .padding(.horizontal)
    }

    private func dysfunctionSection(_ screening: MovementScreeningReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DYSFUNCTION FLAGS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            if screening.dysfunctions.isEmpty {
                Text("No major dysfunction flags detected across FMS/SFMA/FCS/FRC.")
                    .font(.caption)
                    .foregroundStyle(Theme.foundationGreen)
            } else {
                ForEach(screening.dysfunctions.prefix(3)) { dysfunction in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dysfunction.title.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(dysfunction.clinicalSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Correctives: \(dysfunction.correctiveFocus.joined(separator: " • "))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.03))
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
        .padding(.horizontal)
    }

    private func prescriptionSection(_ screening: MovementScreeningReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRESCRIBED PATH")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)
            Text("\(screening.prescription.trainingTrack.rawValue.uppercased()) • \(screening.prescription.equipmentFocus.rawValue.uppercased())")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
            Text(screening.prescription.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Priority: \(screening.prescription.priorityBlocks.joined(separator: " • "))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardBackground)
        )
        .padding(.horizontal)
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
            let resolvedVideoURL = await resolveSelectedVideoURL(from: selectedItem)
            await MainActor.run {
                videoURL = resolvedVideoURL
            }

            for i in 1...20 {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeInOut(duration: 0.2)) {
                    analysisProgress = Double(i) / 20.0
                }
            }

            let result = await SystemScanAnalysisEngine.analyze(
                videoURL: resolvedVideoURL,
                sport: sport,
                goal: goal
            )
            generatedResult = result

            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.spring(response: 0.5)) {
                phase = .results
                gridPulse = false
            }
        }
    }

    private func resolveSelectedVideoURL(from item: PhotosPickerItem?) async -> URL? {
        guard let item else { return nil }
        if let sourceURL = try? await item.loadTransferable(type: URL.self) {
            return sourceURL
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan_clip_\(UUID().uuidString).mov")
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
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
