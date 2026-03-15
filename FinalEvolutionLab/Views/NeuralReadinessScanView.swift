import SwiftUI

struct NeuralReadinessScanView: View {
    let onComplete: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var phase: ScanPhase = .ready
    @State private var tapCount: Int = 0
    @State private var timeRemaining: Double = 10.0
    @State private var scanLineOffset: CGFloat = -1
    @State private var pulseScale: CGFloat = 1.0
    @State private var ripples: [RippleEffect] = []
    @State private var gridPulse: Bool = false
    @State private var scanTask: Task<Void, Never>?

    private enum ScanPhase {
        case ready
        case scanning
        case analyzing
        case complete
    }

    private var readinessScore: Double {
        let tapsPerSecond = Double(tapCount) / 10.0
        return min(100, tapsPerSecond * 12.5)
    }

    private var readinessGrade: String {
        switch readinessScore {
        case 80...: "ELITE"
        case 60..<80: "PRIMED"
        case 40..<60: "READY"
        default: "WARMING UP"
        }
    }

    private var gradeColor: Color {
        switch readinessScore {
        case 80...: Theme.elitePurple
        case 60..<80: Theme.brandBlue
        case 40..<60: Theme.foundationGreen
        default: .orange
        }
    }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            meshBackground
            scanGrid

            VStack(spacing: 0) {
                header
                Spacer()
                centerContent
                Spacer()
                bottomInfo
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            scanTask?.cancel()
        }
    }

    private var meshBackground: some View {
        Theme.meshGradient
            .opacity(0.4)
            .ignoresSafeArea()
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

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                    .symbolEffect(.pulse, isActive: phase == .scanning)

                Text("NEURAL READINESS SCAN")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(3)
            }

            if phase == .scanning {
                Text(String(format: "%.1fs", timeRemaining))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .padding(.top, 20)
    }

    private var centerContent: some View {
        VStack(spacing: 32) {
            switch phase {
            case .ready:
                readyState
            case .scanning:
                scanningState
            case .analyzing:
                analyzingState
            case .complete:
                completeState
            }
        }
    }

    private var readyState: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(Theme.brandBlue.opacity(0.1 + Double(ring) * 0.05), lineWidth: 1)
                        .frame(width: CGFloat(120 + ring * 40), height: CGFloat(120 + ring * 40))
                }

                Circle()
                    .fill(Theme.brandBlue.opacity(0.08))
                    .frame(width: 120, height: 120)

                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)
                    .symbolEffect(.bounce, value: phase)
            }

            VStack(spacing: 8) {
                Text("TAP TEST")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)

                Text("Tap as fast as you can for 10 seconds")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("This calibrates your Neural Drive for the session")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button {
                startScan()
            } label: {
                Text("BEGIN SCAN")
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.brandBlue)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
    }

    private var scanningState: some View {
        ZStack {
            ForEach(ripples) { ripple in
                Circle()
                    .stroke(Theme.brandCyan.opacity(ripple.opacity), lineWidth: 2)
                    .frame(width: ripple.size, height: ripple.size)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.brandBlue.opacity(0.4), Theme.brandBlue.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(pulseScale)

            VStack(spacing: 8) {
                Text("\(tapCount)")
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("TAPS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .contentShape(Rectangle())
        .onTapGesture {
            registerTap()
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: tapCount)
    }

    private var analyzingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(Theme.brandCyan)
                .scaleEffect(1.5)

            Text("ANALYZING NEURAL RESPONSE...")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)
        }
    }

    private var completeState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(gradeColor.opacity(0.1))
                    .frame(width: 140, height: 140)

                Circle()
                    .stroke(gradeColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 140, height: 140)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", readinessScore))
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("NRS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(2)
                }
            }

            VStack(spacing: 6) {
                Text(readinessGrade)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(gradeColor)

                Text("\(tapCount) taps in 10s")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", Double(tapCount) / 10.0))
                        .font(.system(.headline, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                    Text("TAPS/SEC")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", readinessScore))
                        .font(.system(.headline, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                    Text("READINESS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
            }
            .padding(.horizontal, 20)

            Button {
                onComplete(readinessScore)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("ENTER ARENA")
                }
                .font(.system(.subheadline, design: .monospaced, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(gradeColor)
                .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .sensoryFeedback(.success, trigger: phase == .complete)
    }

    private var bottomInfo: some View {
        Group {
            if phase == .scanning {
                Text("TAP ANYWHERE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue.opacity(0.5))
                    .tracking(4)
            } else if phase == .ready {
                Button("SKIP") {
                    onComplete(50)
                    dismiss()
                }
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Skip scan")
                .accessibilityHint("Uses default readiness score and closes")
            }
        }
        .padding(.bottom, 20)
    }

    private func startScan() {
        withAnimation(.spring(response: 0.4)) {
            phase = .scanning
        }
        tapCount = 0
        timeRemaining = 10.0

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            gridPulse = true
        }

        scanTask?.cancel()
        scanTask = Task {
            for _ in 0..<100 {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, phase == .scanning else { return }
                withAnimation { timeRemaining = max(0, timeRemaining - 0.1) }
                if timeRemaining <= 0 {
                    finishScan()
                    return
                }
            }
        }
    }

    private func registerTap() {
        guard phase == .scanning else { return }
        withAnimation(.spring(response: 0.15)) {
            tapCount += 1
            pulseScale = 1.15
        }

        let ripple = RippleEffect()
        ripples.append(ripple)
        withAnimation(.easeOut(duration: 0.6)) {
            if let index = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[index].size = 200
                ripples[index].opacity = 0
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.spring(response: 0.15)) {
                pulseScale = 1.0
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(700))
            ripples.removeAll { $0.id == ripple.id }
        }
    }

    private func finishScan() {
        withAnimation(.spring(response: 0.4)) {
            phase = .analyzing
            gridPulse = false
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.spring(response: 0.5)) {
                phase = .complete
            }
        }
    }
}

struct RippleEffect: Identifiable {
    let id = UUID()
    var size: CGFloat = 40
    var opacity: Double = 0.6
}
