import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

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
    @State private var communityPostState: CommunityPostState = .idle
    @State private var analysisSessionID = UUID()
    @State private var analysisTask: Task<Void, Never>?

    /// Lift-App-parity surfaces (3D replay / form overlay / measurements) presented over the results screen.
    private enum LiftParitySheet: String, Identifiable {
        case replay, measurements
        var id: String { rawValue }
    }
    @State private var activeParitySheet: LiftParitySheet?

    private enum CommunityPostState: Equatable {
        case idle
        case posting
        case posted
        case failed(String)
    }

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
                ToolbarItem(placement: .principal) {
                    FELPreviewLabel(text: FELPremiumCopy.Preview.systemScan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onDisappear { cancelAnalysis() }
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

                Text("Upload a clip to run the training-lab demo scan: scores are synthesized from your goal selection — not ARKit pose, mesh depth, or frontal-plane knee geometry. Full biomechanical capture ships later.")
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
                guard let newItem else { return }
                cancelAnalysis()
                Task {
                    _ = try? await newItem.loadTransferable(type: Data.self)
                    await MainActor.run {
                        startAnalysis()
                    }
                }
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

                Text("Demo pipeline — no live pose mesh or confidence score in this build.")
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
        case 0..<0.25: "BUILDING DEMO PROFILE..."
        case 0.25..<0.5: "SAMPLING FLIGHT WINDOW..."
        case 0.5..<0.75: "PROJECTING VERTICAL ESTIMATE..."
        case 0.75..<1.0: "DERIVING PRQ SAMPLE..."
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

                    Text("Demo scan — illustrative metrics only")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(result.commitsCompetitiveMetrics ? "Measured PRQ" : "Preview PRQ")
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

                        Text(result.commitsCompetitiveMetrics ? "PRQ" : "PREVIEW PRQ")
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

                liftParitySection(result)

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

                if FirebaseBootstrap.isConfigured {
                    VStack(spacing: 10) {
                        if result.commitsCompetitiveMetrics {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task { await postScanToCommunity(result) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up.on.square.fill")
                                    Text("SHARE TO LAB FEED")
                                }
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Theme.brandBlue.opacity(0.95), Theme.brandCyan.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(.rect(cornerRadius: 14))
                            }
                            .disabled(communityPostState == .posting)

                            switch communityPostState {
                            case .idle:
                                EmptyView()
                            case .posting:
                                Text("Publishing to SQL feed…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .posted:
                                Label("Posted — check the Arena Community tab.", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.foundationGreen)
                            case .failed(let msg):
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            Text("Measured scans only for the live feed — this session uses the non-scoring demo pipeline.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
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
        .sheet(item: $activeParitySheet) { sheet in
            let audit = BiomechanicsAudit.fromScanResult(result)
            let analysis = ScanFormAnalysis.make(result: result, audit: audit)
            switch sheet {
            case .replay:
                ScanFormReplayView(result: result, audit: audit, analysis: analysis)
            case .measurements:
                ScanMeasurementsView(analysis: analysis)
            }
        }
    }

    /// Lift-App-parity entry points: 3D form replay (with the optimal-form ghost
    /// overlay) and the body-segment measurement HUD. Reachable after any scan.
    private func liftParitySection(_ result: SystemScanResult) -> some View {
        VStack(spacing: 10) {
            Text("FORM LAB")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            HStack(spacing: 12) {
                parityCard(
                    title: "3D REPLAY",
                    subtitle: "Orbit + ideal ghost",
                    icon: "rotate.3d",
                    tint: Theme.brandCyan
                ) { activeParitySheet = .replay }

                parityCard(
                    title: "MEASUREMENTS",
                    subtitle: "Segments + joints",
                    icon: "ruler.fill",
                    tint: Theme.elitePurple
                ) { activeParitySheet = .measurements }
            }
        }
        .padding(.horizontal)
    }

    private func parityCard(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(1)
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(tint.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.2), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
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

    @MainActor
    private func postScanToCommunity(_ result: SystemScanResult) async {
        guard result.commitsCompetitiveMetrics else {
            communityPostState = .idle
            FelToastCenter.shared.show(
                "Live Lab feed requires a verified measured scan. This clip uses the training-lab demo scorer only.",
                isError: true
            )
            return
        }
        communityPostState = .posting
        let metrics = labPerformanceMetrics(from: result)
        do {
            await TrainingLabSocialBridge.shared.syncPeakPRQFromScanResult(result)
            _ = try await TrainingLabSocialBridge.shared.ensureSqlUserRegistration(displayName: nil)
            let content = """
            PRQ \(String(format: "%.1f", result.prqScore)) · \(result.movementGrade)
            Explosiveness \(String(format: "%.0f", metrics.explosiveness * 100))% · Neural focus \(String(format: "%.0f", metrics.neuralFocus * 100))%
            Vertical \(String(format: "%.1f\"", result.verticalEstimateInches)) · Flight \(String(format: "%.2fs", result.flightTimeSeconds))
            Track: \(result.recommendedTrack)
            """
            try await TrainingLabSocialBridge.shared.createFeedPost(
                content: content,
                gameModeId: nil,
                trainingScore: result.prqScore,
                clipUrl: nil,
                feedSource: "system_scan"
            )
            communityPostState = .posted
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            FelToastCenter.shared.show("Shared to live Lab feed", isError: false)
        } catch {
            communityPostState = .failed(error.localizedDescription)
            FelToastCenter.shared.show(error.localizedDescription, isError: true)
        }
    }

    /// Normalized 0…1 metrics aligned with ``AvatarPerformanceAttributes``-style storytelling (demo scan — no HealthKit vitals).
    private func labPerformanceMetrics(from result: SystemScanResult) -> (explosiveness: Double, neuralFocus: Double) {
        let prqN = min(1.0, max(0.0, result.prqScore / 100.0))
        let vertN = min(1.0, max(0.0, (result.verticalEstimateInches - 18.0) / 18.0))
        let flightN = min(1.0, max(0.0, result.flightTimeSeconds / 0.72))
        let explosiveness = min(1.0, max(0.12, prqN * 0.52 + vertN * 0.38 + flightN * 0.1))
        let neuralFocus = min(1.0, max(0.12, prqN * 0.48 + flightN * 0.37 + (1.0 - vertN) * 0.15))
        return (explosiveness, neuralFocus)
    }

    private func gradeColor(_ score: Double) -> Color {
        switch score {
        case 80...: Theme.elitePurple
        case 60..<80: Theme.brandBlue
        case 40..<60: Theme.foundationGreen
        default: .orange
        }
    }

    private func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
    }

    private func startAnalysis() {
        cancelAnalysis()
        withAnimation(.spring(response: 0.4)) { phase = .analyzing }
        analysisProgress = 0
        let sessionID = UUID()
        analysisSessionID = sessionID

        analysisTask = Task {
            for i in 1...20 {
                do {
                    try Task.checkCancellation()
                } catch {
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard analysisSessionID == sessionID else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        analysisProgress = Double(i) / 20.0
                    }
                }
            }
            do {
                try Task.checkCancellation()
            } catch {
                return
            }
            let result = generateScanResult()
            await MainActor.run {
                guard analysisSessionID == sessionID else { return }
                generatedResult = result
            }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard analysisSessionID == sessionID else { return }
                withAnimation(.spring(response: 0.5)) {
                    phase = .results
                    gridPulse = false
                }
            }
        }
    }

    /// Preview-only synthesis: goal-band randomization — **not** video, ARKit, Luma, or pose measurement.
    /// Competitive PRQ / biomechanics require a future measured pipeline with explicit scan source + confidence metadata.
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

        var notes: [String] = [
            "This session does not measure knee alignment, rib flare, or pelvic tilt — those require pose/mesh confidence in a future build."
        ]
        if basePRQ < 60 {
            notes.append("Lower simulated PRQ — prioritize recovery and repeat attempts when fresh (not an ankle mechanics diagnosis).")
        }
        if baseVertical < 26 {
            notes.append("Lower vertical estimate in this random sample — plyometric progressions are general guidance only.")
        }
        if basePRQ >= 70 {
            notes.append("Higher simulated PRQ band — good candidate for progressive reactive work when readiness allows.")
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
            avatarConfig: avatarConfig,
            source: .demoSynthetic,
            confidence01: 0.35
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
