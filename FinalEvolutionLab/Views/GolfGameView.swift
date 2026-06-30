import SwiftUI

// MARK: - Phase

private enum GolfPhase {
    case ready, aiming, result
}

// MARK: - Hole State

private struct GolfHoleResult {
    let hole: Int
    let strokes: Int
    let scoreName: String   // Eagle, Birdie, Par, Bogey, Double Bogey
    let scoreVsPar: Int     // negative = under par
}

// MARK: - Obstacle Type

private enum GolfObstacle: String {
    case sandTrap  = "Sand Trap"
    case water     = "Water"

    var color: Color {
        switch self {
        case .sandTrap: return Color(red: 0.85, green: 0.78, blue: 0.45)
        case .water:    return Color(red: 0.2,  green: 0.5,  blue: 0.85)
        }
    }

    var strokePenalty: Int {
        switch self {
        case .sandTrap: return 1
        case .water:    return 2
        }
    }
}

// MARK: - Obstacle Layout

private struct GolfObstacleLayout: Identifiable {
    let id: UUID = UUID()
    let type: GolfObstacle
    let position: CGPoint   // normalized 0–1 in field coordinates
    let size: CGSize        // normalized
}

// MARK: - Shot State

private enum ShotState {
    case idle, aiming, draggingBack, ballFlying, landed
}

// MARK: - GolfGameView

struct GolfGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // MARK: Game state
    @State private var phase: GolfPhase = .ready
    @State private var currentHole: Int = 1
    @State private var currentStrokes: Int = 0
    @State private var totalStrokes: Int = 0
    @State private var holeResults: [GolfHoleResult] = []
    @State private var ballOnGreen: Bool = false
    @State private var shotState: ShotState = .idle

    // MARK: Shot mechanic
    @State private var aimAngle: Double = 0.0          // degrees, 0 = straight up
    @State private var pullDistance: CGFloat = 0.0     // drag-back distance (0–80)
    @State private var dragStartLocation: CGPoint = .zero
    @State private var isDraggingBack: Bool = false

    // MARK: Ball position (normalized 0–1, origin bottom-left)
    @State private var ballX: Double = 0.5
    @State private var ballY: Double = 0.1
    @State private var ballAnimX: Double = 0.5
    @State private var ballAnimY: Double = 0.1

    // MARK: Hole layout
    @State private var holePosition: CGPoint = CGPoint(x: 0.5, y: 0.88)
    @State private var obstacles: [GolfObstacleLayout] = []

    // MARK: Feedback
    @State private var feedbackText: String = ""
    @State private var showFeedback: Bool = false
    @State private var penaltyText: String = ""
    @State private var showPenalty: Bool = false

    // MARK: Hole transition
    @State private var showHoleCard: Bool = false
    @State private var holeCardText: String = ""
    @State private var holeCardColor: Color = .white

    // MARK: AI opponent
    private let aiTotalStrokes: Int = Int.random(in: 27...45)

    // MARK: Rewards
    private let XP_CAP: Int = 500
    private let WIN_SHARDS = 50
    private let DRAW_SHARDS = 25
    private let LOSS_SHARDS = 15

    private let accentColor = Color(red: 0.3, green: 0.7, blue: 0.4)

    // Par is 3 per hole
    private let parPerHole = 3
    private var totalPar: Int { parPerHole * 9 }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.08, blue: 0.03), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Golf · Closest to Pin",
                    subtitle: "9 Holes · Par 3 Each · Drag to Aim & Shoot",
                    countdown: 3,
                    accentColor: accentColor,
                    onComplete: { startHole() }
                )

            case .aiming:
                VStack(spacing: 0) {
                    holeHeader
                        .padding(.top, 8)

                    courseView
                        .frame(maxWidth: .infinity)
                        .layoutPriority(1)

                    controlPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                }

                // Feedback overlays
                if showPenalty {
                    penaltyOverlay
                }

                if showHoleCard {
                    holeCardOverlay
                }

            case .result:
                let playerWon = totalStrokes < aiTotalStrokes
                let isDraw = totalStrokes == aiTotalStrokes
                let scoreVsPar = totalStrokes - totalPar
                ResultScreen(
                    winner: playerWon ? .p1 : (isDraw ? .draw : .p2),
                    p1Score: totalStrokes,
                    p2Score: aiTotalStrokes,
                    title: "Golf · 9 Holes",
                    accentColor: accentColor,
                    prqGain: playerWon ? 10 : (isDraw ? 4 : 2),
                    prqCurrent: viewModel.effectiveMetrics.prqScore,
                    modeAttributeLabel: scoreVsPar <= 0 ? "Under Par" : "Over Par",
                    modeAttributeValue: max(0, 1.0 - Double(abs(scoreVsPar)) / 18.0),
                    onReturn: { dismiss() }
                )
                .onAppear { grantShards(playerWon: playerWon, isDraw: isDraw) }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Hole Header

    private var holeHeader: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("HOLE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(currentHole)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1, height: 36)

            VStack(spacing: 2) {
                Text("PAR")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(parPerHole)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1, height: 36)

            VStack(spacing: 2) {
                Text("SHOTS")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Text("\(currentStrokes)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1, height: 36)

            VStack(spacing: 2) {
                Text("TOTAL")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                let svp = totalStrokes - (holeResults.count * parPerHole)
                Text(svp == 0 ? "E" : (svp > 0 ? "+\(svp)" : "\(svp)"))
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(svp < 0 ? accentColor : (svp == 0 ? .white : .red))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Course View (overhead 2D)

    private var courseView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Fairway
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.12, green: 0.32, blue: 0.14))

                // Rough border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.08, green: 0.22, blue: 0.1), lineWidth: 8)

                // Green around hole
                Circle()
                    .fill(Color(red: 0.15, green: 0.45, blue: 0.18))
                    .frame(width: 80, height: 80)
                    .position(x: holePosition.x * w, y: (1.0 - holePosition.y) * h)

                // Obstacles
                ForEach(obstacles) { obs in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(obs.type.color.opacity(0.85))
                        .frame(
                            width:  obs.size.width  * w,
                            height: obs.size.height * h
                        )
                        .position(
                            x: obs.position.x * w,
                            y: (1.0 - obs.position.y) * h
                        )
                        .overlay(
                            Text(obs.type == .sandTrap ? "S" : "W")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(obs.type == .water ? .white : .black)
                                .position(
                                    x: obs.position.x * w,
                                    y: (1.0 - obs.position.y) * h
                                )
                        )
                }

                // Flag at hole
                let holeX = holePosition.x * w
                let holeY = (1.0 - holePosition.y) * h
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 18, height: 18)
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2, height: 20)
                        .offset(y: -10)
                    Triangle()
                        .fill(accentColor)
                        .frame(width: 10, height: 8)
                        .offset(x: 5, y: -18)
                }
                .position(x: holeX, y: holeY)

                // Aim arrow from ball
                if shotState == .idle || shotState == .aiming || shotState == .draggingBack {
                    AimArrow(angle: aimAngle, pullback: pullDistance)
                        .stroke(accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(aimAngle))
                        .position(x: ballAnimX * w, y: (1.0 - ballAnimY) * h)
                }

                // Ball
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(white: 0.75)],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 10
                        )
                    )
                    .frame(width: 18, height: 18)
                    .shadow(color: .white.opacity(0.5), radius: 4)
                    .position(x: ballAnimX * w, y: (1.0 - ballAnimY) * h)
                    .animation(.easeOut(duration: 0.5), value: ballAnimX)
                    .animation(.easeOut(duration: 0.5), value: ballAnimY)

                // Shot feedback
                if showFeedback {
                    Text(feedbackText)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: accentColor.opacity(0.6), radius: 12)
                        .position(x: w / 2, y: h / 2)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in onDragChanged(v, in: geo.size) }
                    .onEnded   { v in onDragEnded(v,   in: geo.size) }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Direction indicator
                VStack(spacing: 4) {
                    Text("DIRECTION")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                    ZStack {
                        Circle()
                            .fill(Theme.cardBackground)
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(accentColor)
                            .rotationEffect(.degrees(aimAngle))
                            .animation(.interactiveSpring(response: 0.15), value: aimAngle)
                    }
                }

                // Power indicator
                VStack(spacing: 4) {
                    Text("POWER")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.cardBackground)
                                .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.brandCyan, accentColor, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * powerRatio))
                                .animation(.interactiveSpring(response: 0.1), value: pullDistance)
                        }
                    }
                    .frame(height: 14)
                    Text("\(Int(powerRatio * 100))%")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
            )

            // Instructions
            HStack {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(accentColor)
                Text("Drag to rotate aim · Pull back & release to shoot")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Hole scores summary
            if !holeResults.isEmpty {
                holeScoreSummary
            }
        }
    }

    private var powerRatio: CGFloat {
        min(1.0, pullDistance / 80.0)
    }

    // MARK: - Hole Score Summary

    private var holeScoreSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(holeResults, id: \.hole) { result in
                    VStack(spacing: 2) {
                        Text("H\(result.hole)")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("\(result.strokes)")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(scoreSymbol(result.scoreVsPar))
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(scoreColor(result.scoreVsPar))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.cardBackground.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(scoreColor(result.scoreVsPar).opacity(0.4), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func scoreSymbol(_ vsPar: Int) -> String {
        switch vsPar {
        case ..<(-1): return "🦅"
        case -1:      return "B"
        case 0:       return "="
        case 1:       return "+"
        default:      return "++"
        }
    }

    private func scoreColor(_ vsPar: Int) -> Color {
        switch vsPar {
        case ..<0:   return accentColor
        case 0:      return .white
        case 1:      return .orange
        default:     return .red
        }
    }

    // MARK: - Overlays

    private var penaltyOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(penaltyText)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.5), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private var holeCardOverlay: some View {
        VStack(spacing: 12) {
            Text("HOLE \(holeResults.last?.hole ?? currentHole) COMPLETE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)
            Text(holeCardText)
                .font(.system(size: 32, weight: .black))
                .italic()
                .foregroundStyle(holeCardColor)
                .shadow(color: holeCardColor.opacity(0.5), radius: 16)
            if let last = holeResults.last {
                Text("\(last.strokes) strokes · Par \(parPerHole)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground.opacity(0.95))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(holeCardColor.opacity(0.3), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.5), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    // MARK: - Drag Gesture

    private func onDragChanged(_ v: DragGesture.Value, in size: CGSize) {
        guard shotState == .idle || shotState == .aiming || shotState == .draggingBack else { return }

        if shotState == .idle {
            dragStartLocation = v.startLocation
            shotState = .aiming
        }

        let dx = v.location.x - dragStartLocation.x
        let dy = v.location.y - dragStartLocation.y

        // First phase: rotate aim based on drag direction
        let dist = sqrt(dx * dx + dy * dy)
        if dist > 8 {
            shotState = .draggingBack
            // Aim angle: atan2 from ball toward drag, convert to degrees
            let angle = atan2(dx, -dy) * 180.0 / .pi
            aimAngle = angle

            // Pull distance: perpendicular drag-back component
            pullDistance = min(80, dist * 0.7)
        }
    }

    private func onDragEnded(_ v: DragGesture.Value, in size: CGSize) {
        guard shotState == .draggingBack || shotState == .aiming else {
            shotState = .idle
            return
        }
        let power = Double(pullDistance / 80.0)
        fireShot(power: power, fieldSize: size)
    }

    // MARK: - Shot Logic

    private func fireShot(power: Double, fieldSize: CGSize) {
        guard shotState != .ballFlying, !ballOnGreen else { return }
        shotState = .ballFlying
        currentStrokes += 1

        // Convert aim angle (degrees from north, clockwise) to vector
        let radians = aimAngle * .pi / 180.0
        let dirX = sin(radians)
        let dirY = cos(radians)

        // Distance scales with power (max ~0.6 of field)
        let maxDist = 0.55 * power
        let newBallX = clamp(ballX + dirX * maxDist, 0.05, 0.95)
        let newBallY = clamp(ballY + dirY * maxDist, 0.05, 0.95)

        // Check obstacle collision
        let hitObstacle = obstacles.first(where: { obs in
            let midX = newBallX
            let midY = newBallY
            let obsLeft   = obs.position.x - obs.size.width / 2
            let obsRight  = obs.position.x + obs.size.width / 2
            let obsBottom = obs.position.y - obs.size.height / 2
            let obsTop    = obs.position.y + obs.size.height / 2
            return midX >= obsLeft && midX <= obsRight && midY >= obsBottom && midY <= obsTop
        })

        Task {
            await MainActor.run {
                ballAnimX = newBallX
                ballAnimY = newBallY
            }

            try? await Task.sleep(for: .milliseconds(550))

            await MainActor.run {
                if let obs = hitObstacle {
                    applyObstaclePenalty(obs)
                } else {
                    ballX = newBallX
                    ballY = newBallY
                    checkIfHoled()
                }
                pullDistance = 0
                shotState = .idle
            }
        }
    }

    private func applyObstaclePenalty(_ obs: GolfObstacleLayout) {
        currentStrokes += obs.type.strokePenalty
        if obs.type == .water {
            // Reset ball to previous position
            ballAnimX = ballX
            ballAnimY = ballY
            penaltyText = "Water Hazard!\n+\(obs.type.strokePenalty) Strokes · Ball Reset"
        } else {
            ballX = ballAnimX
            ballY = ballAnimY
            penaltyText = "Sand Trap!\n+\(obs.type.strokePenalty) Stroke"
        }
        withAnimation(.spring(response: 0.3)) { showPenalty = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1600))
            await MainActor.run {
                withAnimation { showPenalty = false }
            }
        }
    }

    private func checkIfHoled() {
        let distToHole = sqrt(
            pow(ballX - Double(holePosition.x), 2) +
            pow(ballY - Double(holePosition.y), 2)
        )

        if distToHole < 0.10 {
            ballOnGreen = true
            recordHole()
        } else if currentStrokes >= parPerHole + 3 {
            // Max strokes cap at double bogey + 1: force complete
            ballOnGreen = true
            recordHole()
        }
    }

    private func recordHole() {
        let scoreVsPar = currentStrokes - parPerHole
        let name: String
        let color: Color
        switch scoreVsPar {
        case ..<(-1):
            name = "Eagle"
            color = accentColor
        case -1:
            name = "Birdie"
            color = Theme.brandCyan
        case 0:
            name = "Par"
            color = .white
        case 1:
            name = "Bogey"
            color = .orange
        default:
            name = "Double Bogey"
            color = .red
        }

        holeResults.append(GolfHoleResult(
            hole: currentHole,
            strokes: currentStrokes,
            scoreName: name,
            scoreVsPar: scoreVsPar
        ))
        totalStrokes += currentStrokes

        holeCardText = name
        holeCardColor = color

        withAnimation(.spring(response: 0.3)) { showHoleCard = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            await MainActor.run {
                withAnimation { showHoleCard = false }
                if currentHole < 9 {
                    advanceHole()
                } else {
                    phase = .result
                }
            }
        }
    }

    private func advanceHole() {
        currentHole += 1
        currentStrokes = 0
        ballOnGreen = false
        ballX = 0.5
        ballY = 0.1
        ballAnimX = 0.5
        ballAnimY = 0.1
        aimAngle = 0
        pullDistance = 0
        shotState = .idle
        generateHoleLayout()
    }

    private func startHole() {
        phase = .aiming
        generateHoleLayout()
    }

    private func generateHoleLayout() {
        // Randomize hole position in upper portion of field
        holePosition = CGPoint(
            x: Double.random(in: 0.25...0.75),
            y: Double.random(in: 0.72...0.88)
        )

        // Generate 2–3 obstacles
        var newObstacles: [GolfObstacleLayout] = []
        let count = Int.random(in: 2...3)
        let types: [GolfObstacle] = count > 2 ? [.sandTrap, .water, .sandTrap] : [.sandTrap, .water]

        for (i, obsType) in types.prefix(count).enumerated() {
            let baseY = 0.30 + Double(i) * 0.18
            newObstacles.append(GolfObstacleLayout(
                type: obsType,
                position: CGPoint(
                    x: Double.random(in: 0.25...0.75),
                    y: baseY + Double.random(in: -0.05...0.05)
                ),
                size: CGSize(
                    width:  Double.random(in: 0.15...0.22),
                    height: Double.random(in: 0.08...0.12)
                )
            ))
        }
        obstacles = newObstacles
    }

    // MARK: - Rewards

    private func grantShards(playerWon: Bool, isDraw: Bool) {
        let earned = playerWon ? WIN_SHARDS : (isDraw ? DRAW_SHARDS : LOSS_SHARDS)
        viewModel.profile.evolutionShards += min(earned, XP_CAP)
    }

    // MARK: - Helpers

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, v))
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Aim Arrow Shape

private struct AimArrow: Shape {
    let angle: Double     // unused directly here; caller applies .rotationEffect
    let pullback: CGFloat // 0–80

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let len: CGFloat = 40 + pullback * 0.4

        // Shaft line (pointing up from center)
        p.move(to: CGPoint(x: cx, y: cy))
        p.addLine(to: CGPoint(x: cx, y: cy - len))

        // Arrow head
        let headLen: CGFloat = 10
        p.move(to: CGPoint(x: cx - 6, y: cy - len + headLen))
        p.addLine(to: CGPoint(x: cx, y: cy - len))
        p.addLine(to: CGPoint(x: cx + 6, y: cy - len + headLen))
        return p
    }
}
