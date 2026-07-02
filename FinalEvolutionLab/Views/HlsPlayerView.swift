import SwiftUI
import AVKit

/// A native AVPlayer-based HLS player view with time-synchronized telemetry overlays.
/// Maps heart rate, cadence, and power curves to the active HLS playback timeline.
struct HlsPlayerView: View {
    let videoTitle: String
    let streamURL: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    
    // Biomechanical telemetry states
    @State private var heartRate: Double = 120.0
    @State private var cadence: Double = 80.0
    @State private var power: Double = 180.0
    @State private var currentTime: Double = 0.0
    @State private var duration: Double = 0.0
    @State private var isPlaying = false
    
    // Rolling telemetry history for the live graph
    @State private var telemetryHistory: [TelemetryDataPoint] = []
    private let maxHistoryCount = 40
    
    struct TelemetryDataPoint: Identifiable {
        let id = UUID()
        let relativeTime: Double
        let heartRate: Double
        let cadence: Double
        let power: Double
    }
    
    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            
            // 1. Native AVPlayer
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.1))
            } else {
                ProgressView("Loading HLS Feed...")
                    .tint(Theme.brandCyan)
                    .foregroundStyle(.white)
            }
            
            // 2. Neon overlay aesthetics
            scanGrid
                .opacity(0.1)
            
            // 3. Telemetry Overlay Dashboard
            VStack {
                headerOverlay
                Spacer()
                telemetryOverlayHUD
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    cleanUpPlayer()
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Portal")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                }
            }
            ToolbarItem(placement: .principal) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.hlsDemo)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanUpPlayer()
        }
    }
    
    // MARK: - Subviews
    
    private var scanGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 36
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for col in 0...cols {
                let x = CGFloat(col) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Theme.brandCyan.opacity(0.08)), lineWidth: 0.5)
            }
            for row in 0...rows {
                let y = CGFloat(row) * spacing
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Theme.brandCyan.opacity(0.08)), lineWidth: 0.5)
            }
        }
    }
    
    private var headerOverlay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LIVE STREAM PORTAL")
                    .font(.system(.caption2, design: .monospaced, weight: .black))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                Text(videoTitle)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.65))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            )
            Spacer()
            
            // Sync status badge
            HStack(spacing: 6) {
                Circle()
                    .fill(isPlaying ? Theme.neonGreen : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isPlaying ? "TELEMETRY SYNCED" : "PAUSED")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.65))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            )
        }
    }
    
    private var telemetryOverlayHUD: some View {
        VStack(spacing: 12) {
            // Numbers readout
            HStack(spacing: 12) {
                telemetryPill(
                    title: "HEART RATE",
                    value: String(format: "%.0f", heartRate),
                    unit: "BPM",
                    color: Color.red,
                    icon: "heart.fill"
                )
                telemetryPill(
                    title: "CADENCE",
                    value: String(format: "%.0f", cadence),
                    unit: "RPM",
                    color: Theme.brandCyan,
                    icon: "circle.grid.cross.fill"
                )
                telemetryPill(
                    title: "KINETIC POWER",
                    value: String(format: "%.0f", power),
                    unit: "WATTS",
                    color: Theme.elitePurple,
                    icon: "bolt.fill"
                )
            }
            
            // Rolling chart
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BIOMECHANICAL POWER TIMELINE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(String(format: "Timeline: %.1fs / %.1fs", currentTime, duration))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan.opacity(0.8))
                }
                
                // Drawing Custom Telemetry Timeline Line Chart
                GeometryReader { geo in
                    ZStack {
                        // Graph Gridlines
                        Path { path in
                            let count = 4
                            for i in 1..<count {
                                let y = geo.size.height * CGFloat(i) / CGFloat(count)
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geo.size.width, y: y))
                            }
                        }
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        
                        // Heart rate curve (Red)
                        drawTimelineCurve(for: \.heartRate, range: 100...180, color: Color.red.opacity(0.85), size: geo.size)
                        
                        // Power curve (Purple)
                        drawTimelineCurve(for: \.power, range: 100...350, color: Theme.elitePurple.opacity(0.85), size: geo.size)
                        
                        // Cadence curve (Cyan)
                        drawTimelineCurve(for: \.cadence, range: 60...120, color: Theme.brandCyan.opacity(0.85), size: geo.size)
                    }
                }
                .frame(height: 80)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
            )
        }
    }
    
    private func telemetryPill(title: String, value: String, unit: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }
    
    // MARK: - Graph Math Drawing
    
    private func drawTimelineCurve(
        for keyPath: KeyPath<TelemetryDataPoint, Double>,
        range: ClosedRange<Double>,
        color: Color,
        size: CGSize
    ) -> some View {
        Path { path in
            guard telemetryHistory.count > 1 else { return }
            
            let minVal = range.lowerBound
            let maxVal = range.upperBound
            let span = maxVal - minVal
            
            for (idx, pt) in telemetryHistory.enumerated() {
                let val = pt[keyPath: keyPath]
                let normalizedVal = max(0, min(1, (val - minVal) / span))
                
                let x = size.width * CGFloat(idx) / CGFloat(maxHistoryCount - 1)
                // Y=0 is at top in SwiftUI canvas, so invert
                let y = size.height * (1.0 - CGFloat(normalizedVal))
                
                if idx == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - AVPlayer Initialization & Telemetry Sync
    
    private func setupPlayer() {
        guard let url = URL(string: streamURL) else { return }
        
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer
        
        // Start playback
        avPlayer.play()
        self.isPlaying = true
        
        // Setup observer for time synchrony
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak avPlayer] time in
            guard let avPlayer = avPlayer else { return }
            
            let seconds = time.seconds
            self.currentTime = seconds
            
            if let durationTime = avPlayer.currentItem?.duration, durationTime.isNumeric {
                self.duration = durationTime.seconds
            }
            
            self.isPlaying = avPlayer.rate > 0
            
            // Compute synchronized telemetry based on the exact timeline position
            self.computeSyncedTelemetry(at: seconds)
        }
    }
    
    private func computeSyncedTelemetry(at timeInSeconds: Double) {
        // Heart rate: oscillates naturally between 120 and 155 based on video time
        let hr = 132.0 + sin(timeInSeconds / 12.0) * 14.0 + cos(timeInSeconds / 4.0) * 3.0
        
        // Cadence: stabilizes around 85-92 RPM
        let cad = 86.0 + sin(timeInSeconds / 8.0) * 5.0 + cos(timeInSeconds / 3.0) * 2.0
        
        // Kinetic Power: fluctuates dynamically between 170 and 290 Watts
        let pwr = 215.0 + sin(timeInSeconds / 6.0) * 45.0 + cos(timeInSeconds / 2.0) * 12.0
        
        self.heartRate = hr
        self.cadence = cad
        self.power = pwr
        
        // Add new synchronized data point
        let newPt = TelemetryDataPoint(relativeTime: timeInSeconds, heartRate: hr, cadence: cad, power: pwr)
        telemetryHistory.append(newPt)
        
        // Cap history to scrolling width limit
        if telemetryHistory.count > maxHistoryCount {
            telemetryHistory.removeFirst()
        }
    }
    
    private func cleanUpPlayer() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
    }
}
