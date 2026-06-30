import SwiftUI

// MARK: - Phase

private enum FBPhase {
    case ready, catchRoute, run, touchdown, turnover, result
}

// MARK: - Route Type

private enum RouteType: String, CaseIterable {
    case slant   = "SLANT"
    case corner  = "CORNER"
    case post    = "POST"
    case fly     = "FLY"
    case out     = "OUT"

    var yards: Int {
        switch self {
        case .slant:  return 5
        case .corner: return 9
        case .post:   return 12
        case .fly:    return 20
        case .out:    return 8
        }
    }

    var windowSeconds: Double {
        switch self {
        case .slant:  return 1.8
        case .corner: return 1.4
        case .post:   return 1.2
        case .fly:    return 1.6
        case .out:    return 1.5
        }
    }
}

// MARK: - Defender Dodge Direction

private enum DodgeDirection {
    case left, right, none
}

// MARK: - Constants

private let XP_CAP_PER_SESSION = 500
private let MAX_DOWNS = 4
private let YARDS_TO_GO_INITIAL = 10
private let TD_YARDS = 100

// MARK: - Main View

struct FootballGameView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss

    // Game state
    @State private var phase: FBPhase = .ready
    @State private var down: Int = 1
    @State private var yardsToGo: Int = YARDS_TO_GO_INITIAL
    @State private var yardLine: Int = 25     // starts at own 25
    @State private var playClock: Int = 40
    @State private var rewardGranted: Bool = false

    // Catch phase
    @State private var currentRoute: RouteType = .slant
    @State private var receiverX: CGFloat = 0.5
    @State private var receiverY: CGFloat = 0.5
    @State private var routeProgress: CGFloat = 0.0    // 0→1 across route
    @State private var routeTask: Task<Void, Never>? = nil
    @State private var windowOpen: Bool = false
    @State private var playerThrew: Bool = false
    @State private var catchResult: Bool = false

    // Run phase
    @State private var runMeter: Double = 0.0          // 0→1 progress toward first down
    @State private var defenderPosition: CGFloat = 0.3  // 0=left, 1=right
    @State private var playerPosition: CGFloat = 0.5
    @State private var runTask: Task<Void, Never>? = nil
    @State private var yardsGained: Int = 0
    @State private var dodgeLabel: String = ""
    @State private var showDodgeLabel: Bool = false
    @State private var jukeCount: Int = 0

    // Clock task
    @State private var clockTask: Task<Void, Never>? = nil

    // Effects
    @State private var tdFlash: Bool = false
    @State private var tdScale: CGFloat = 0.5
    @State private var fireworkPositions: [CGPoint] = []
    @State private var screenShake: CGFloat = 0
    @State private var showPlayResult: Bool = false
    @State private var playResultLabel: String = ""
    @State private var playResultColor: Color = .white

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.02), Theme.deepBlack],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                GetReadyScreen(
                    title: "Kick Return",
                    subtitle: "4 Downs · Reach the end zone",
                    countdown: 3,
                    accentColor: gameMode.accentColor,
                    onComplete: { startDrive() }
                )
            case .catchRoute:
                catchBody
            case .run:
                runBody
            case .touchdown:
                touchdownBody
            case .turnover:
                turnoverBody
            case .result:
                resultBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    cancelAllTasks()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { cancelAllTasks() }
    }

    // MARK: - HUD

    private var hudBar: some View {
        HStack(spacing: 0) {
            // Down & distance
            VStack(spacing: 2) {
                Text(downLabel)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(distanceLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(gameMode.accentColor)
            }
            .frame(maxWidth: .infinity)

            // Yard line
            VStack(spacing: 2) {
                Text("OWN \(yardLine)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("YARD LINE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)

            // Play clock
            VStack(spacing: 2) {
                Text("\(playClock)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(playClock <= 10 ? .red : .white)
                    .contentTransition(.numericText())
                Text("CLOCK")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.cardBackground)
    }

    private var downLabel: String {
        switch down {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        case 4: return "4TH"
        default: return "\(down)TH"
        }
    }

    private var distanceLabel: String {
        if yardLine >= 90 { return "& GOAL" }
        return "& \(yardsToGo)"
    }

    // MARK: - Catch Phase Body

    private var catchBody: some View {
        GeometryReader { geo in
            ZStack {
                // Field hash marks
                fieldLines(geo: geo)

                // Route path indicator
                routePath(geo: geo)

                // Receiver dot
                Circle()
                    .fill(Theme.brandCyan)
                    .frame(width: 28, height: 28)
                    .shadow(color: Theme.brandCyan.opacity(0.5), radius: 8)
                    .position(
                        x: geo.size.width * receiverX,
                        y: geo.size.height * receiverY
                    )
                    .animation(.linear(duration: 0.05), value: receiverX)
                    .animation(.linear(duration: 0.05), value: receiverY)

                // Throw window flash
                if windowOpen && !playerThrew {
                    Circle()
                        .stroke(Color.green.opacity(0.6), lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .position(
                            x: geo.size.width * receiverX,
                            y: geo.size.height * receiverY
                        )
                        .animation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true), value: windowOpen)
                }

                VStack(spacing: 0) {
                    hudBar

                    Spacer()

                    // Play result banner
                    if showPlayResult {
                        Text(playResultLabel)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(playResultColor)
                            .shadow(color: playResultColor.opacity(0.4), radius: 10)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(playResultColor.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(playResultColor.opacity(0.3), lineWidth: 1))
                            )
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Instruction
                    VStack(spacing: 6) {
                        Text("ROUTE: \(currentRoute.rawValue)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(gameMode.accentColor)
                            .tracking(2)
                        Text(windowOpen ? "TAP TO THROW!" : (playerThrew ? "" : "WATCH THE ROUTE…"))
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(windowOpen ? .green : .white.opacity(0.4))
                    }
                    .padding(.bottom, 24)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .contentShape(Rectangle())
            .onTapGesture { handleThrow() }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func fieldLines(geo: GeometryProxy) -> some View {
        // Yard line stripes
        let stripeCount = 8
        ForEach(0..<stripeCount, id: \.self) { i in
            let y = geo.size.height * (Double(i + 1) / Double(stripeCount + 1))
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .offset(y: y - geo.size.height / 2)
        }

        // End zone hash
        Rectangle()
            .fill(Theme.foundationGreen.opacity(0.08))
            .frame(height: 40)
            .offset(y: -geo.size.height / 2 + 20)

        Text("END ZONE")
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(Theme.foundationGreen.opacity(0.3))
            .tracking(4)
            .offset(y: -geo.size.height / 2 + 20)
    }

    @ViewBuilder
    private func routePath(geo: GeometryProxy) -> some View {
        // Simple directional arrow showing route
        let start = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.75)
        let routeEnd: CGPoint = {
            switch currentRoute {
            case .slant:   return CGPoint(x: geo.size.width * 0.65, y: geo.size.height * 0.35)
            case .corner:  return CGPoint(x: geo.size.width * 0.75, y: geo.size.height * 0.25)
            case .post:    return CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.2)
            case .fly:     return CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.1)
            case .out:     return CGPoint(x: geo.size.width * 0.8, y: geo.size.height * 0.5)
            }
        }()

        Path { p in
            p.move(to: start)
            p.addLine(to: routeEnd)
        }
        .stroke(
            LinearGradient(
                colors: [Theme.brandCyan.opacity(0.0), Theme.brandCyan.opacity(0.25)],
                startPoint: .bottom,
                endPoint: .top
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 4])
        )
    }

    // MARK: - Run Phase Body

    private var runBody: some View {
        GeometryReader { geo in
            ZStack {
                // Field
                fieldLines(geo: geo)

                // Defender
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 30, height: 44)
                    .overlay(
                        Image(systemName: "figure.run")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .position(x: geo.size.width * defenderPosition, y: geo.size.height * 0.42)
                    .animation(.easeInOut(duration: 0.4), value: defenderPosition)

                // Player
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.brandCyan)
                    .frame(width: 30, height: 44)
                    .overlay(
                        Image(systemName: "figure.american.football")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    )
                    .position(x: geo.size.width * playerPosition, y: geo.size.height * 0.58)
                    .animation(.spring(response: 0.25), value: playerPosition)

                // Progress bar
                VStack(spacing: 0) {
                    Spacer()
                    progressBar(geo: geo)
                }

                VStack(spacing: 0) {
                    hudBar
                    Spacer()

                    // Dodge label
                    if showDodgeLabel {
                        Text(dodgeLabel)
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.4), radius: 8)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        Text("SWIPE LEFT/RIGHT TO JUKE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .tracking(2)
                        Text("TAP TO SPRINT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                            .tracking(2)
                    }
                    .padding(.bottom, 30)
                }
                .frame(width: geo.size.width)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 25)
                    .onEnded { val in
                        if val.translation.width < -30 {
                            handleDodge(.left)
                        } else if val.translation.width > 30 {
                            handleDodge(.right)
                        }
                    }
            )
            .onTapGesture { advanceRun(yards: 1) }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func progressBar(geo: GeometryProxy) -> some View {
        VStack(spacing: 4) {
            Text("\(yardsGained) YDS GAINED")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Theme.brandCyan, Theme.foundationGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(runMeter) - 40), height: 12)
                    .animation(.spring(response: 0.3), value: runMeter)
            }
            .padding(.horizontal, 20)

            // First down marker
            Text(yardsToGo > 0 ? "NEED \(yardsToGo) MORE YDS" : "FIRST DOWN!")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(yardsToGo <= 0 ? Theme.foundationGreen : .secondary)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Touchdown Body

    private var touchdownBody: some View {
        ZStack {
            // Fireworks
            ForEach(Array(fireworkPositions.enumerated()), id: \.offset) { _, pos in
                Circle()
                    .fill(
                        [Color.yellow, Color.orange, gameMode.accentColor, Color.green, Theme.brandCyan].randomElement() ?? .yellow
                    )
                    .frame(width: CGFloat.random(in: 6...18), height: CGFloat.random(in: 6...18))
                    .position(pos)
                    .opacity(tdFlash ? 0 : 1)
                    .animation(.easeOut(duration: 1.2), value: tdFlash)
            }

            VStack(spacing: 24) {
                Spacer()

                Text("TOUCHDOWN!")
                    .font(.system(size: 44, weight: .black))
                    .italic()
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 20)
                    .scaleEffect(tdScale)
                    .opacity(tdFlash ? 1 : 0)

                HStack(spacing: 8) {
                    Image(systemName: "football.fill")
                        .foregroundStyle(.orange)
                    Text("6 POINTS")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .opacity(tdFlash ? 1 : 0)

                Spacer()
            }
        }
    }

    // MARK: - Turnover Body

    private var turnoverBody: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("TURNOVER ON DOWNS")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(.red)
                .tracking(2)

            Text("You were stopped on \(downLabel) down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()
        }
    }

    // MARK: - Result Body

    private var resultBody: some View {
        let didScore = yardLine >= 100
        let winner: ResultScreen.ResultWinner = didScore ? .p1 : .p2
        let shards: Int = winner == .p1 ? 50 : 15
        return ResultScreen(
            winner: winner,
            p1Score: didScore ? 6 : 0,
            p2Score: didScore ? 0 : 7,
            title: "Kick Return",
            accentColor: gameMode.accentColor,
            prqGain: winner == .p1 ? 14 : 3,
            prqCurrent: viewModel.effectiveMetrics.prqScore,
            modeAttributeLabel: "YARDS",
            modeAttributeValue: min(1.0, Double(yardLine) / 100.0),
            onReturn: { dismiss() }
        )
        .onAppear { grantRewards(shards: shards) }
    }

    // MARK: - Logic: Drive Start

    private func startDrive() {
        down = 1
        yardsToGo = YARDS_TO_GO_INITIAL
        yardLine = 25
        playClock = 40
        phase = .catchRoute
        setupCatchPhase()
        startClock()
    }

    private func setupCatchPhase() {
        currentRoute = RouteType.allCases.randomElement() ?? .slant
        receiverX = 0.5
        receiverY = 0.75
        routeProgress = 0.0
        windowOpen = false
        playerThrew = false
        showPlayResult = false
        startRoute()
    }

    private func startRoute() {
        routeTask?.cancel()
        routeTask = Task {
            let totalSteps = 60
            let windowStart = Int(Double(totalSteps) * 0.50)
            let windowEnd   = Int(Double(totalSteps) * 0.75)

            let endPoint: (CGFloat, CGFloat) = routeEndPoint(for: currentRoute)

            for step in 0...totalSteps {
                guard !Task.isCancelled else { return }
                let t = CGFloat(step) / CGFloat(totalSteps)
                let nx = 0.5 + (endPoint.0 - 0.5) * t
                let ny = 0.75 + (endPoint.1 - 0.75) * t

                await MainActor.run {
                    receiverX = nx
                    receiverY = ny
                    routeProgress = t
                    windowOpen = (step >= windowStart && step <= windowEnd)
                }
                try? await Task.sleep(for: .milliseconds(30))
            }

            // Route ran — no throw window left
            await MainActor.run {
                if !playerThrew { handleIncompletionOrSack() }
            }
        }
    }

    private func routeEndPoint(for route: RouteType) -> (CGFloat, CGFloat) {
        switch route {
        case .slant:   return (0.65, 0.35)
        case .corner:  return (0.75, 0.25)
        case .post:    return (0.5, 0.2)
        case .fly:     return (0.5, 0.1)
        case .out:     return (0.8, 0.5)
        }
    }

    private func handleThrow() {
        guard phase == .catchRoute, !playerThrew else { return }
        playerThrew = true
        routeTask?.cancel()
        clockTask?.cancel()

        let caught = windowOpen
        catchResult = caught

        if caught {
            // Successful catch — go to run phase
            let gained = currentRoute.yards
            yardsGained = 0
            runMeter = 0.0
            defenderPosition = Double.random(in: 0.3...0.7)
            playerPosition = 0.5
            jukeCount = 0

            withAnimation {
                playResultLabel = "CAUGHT! +\(gained) YDS AVAILABLE"
                playResultColor = Theme.brandCyan
                showPlayResult = true
            }

            Task {
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    showPlayResult = false
                    phase = .run
                    startRunPhase(yards: gained)
                }
            }
        } else {
            handleIncompletionOrSack()
        }
    }

    private func handleIncompletionOrSack() {
        clockTask?.cancel()
        withAnimation {
            playResultLabel = "INCOMPLETE"
            playResultColor = .red
            showPlayResult = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            await MainActor.run {
                showPlayResult = false
                advanceDown(yardsGained: 0)
            }
        }
    }

    // MARK: - Run Phase

    private func startRunPhase(yards: Int) {
        playClock = 40
        startClock()
        // runTask drives the defender AI
        runTask?.cancel()
        runTask = Task {
            while !Task.isCancelled && phase == .run {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { break }
                // Defender chases player
                await MainActor.run {
                    let diff = playerPosition - defenderPosition
                    defenderPosition += diff * 0.15
                }
            }
        }
    }

    private func handleDodge(_ direction: DodgeDirection) {
        guard phase == .run else { return }
        let move: CGFloat = direction == .left ? -0.18 : 0.18
        playerPosition = max(0.1, min(0.9, playerPosition + move))
        jukeCount += 1

        let labels = ["JUKE!", "SPIN MOVE!", "STIFF ARM!", "HURDLE!", "CUTBACK!"]
        dodgeLabel = labels[jukeCount % labels.count]
        withAnimation(.spring(response: 0.2)) { showDodgeLabel = true }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { withAnimation { showDodgeLabel = false } }
        }

        advanceRun(yards: 3)
    }

    private func advanceRun(yards: Int) {
        guard phase == .run else { return }
        yardsGained += yards
        yardLine = min(100, yardLine + yards)
        let needed = yardsToGo > 0 ? yardsToGo : 0
        let progress = min(1.0, Double(yardsGained) / Double(max(needed, 5)))
        runMeter = progress

        if yardLine >= 100 {
            // TOUCHDOWN
            clockTask?.cancel()
            runTask?.cancel()
            phase = .touchdown
            spawnFireworks()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                tdScale = 1.0
                tdFlash = true
            }
            Task {
                try? await Task.sleep(for: .seconds(3.0))
                await MainActor.run { phase = .result }
            }
        } else if yardsGained >= yardsToGo {
            // First down!
            let newYardsToGo = max(0, 100 - yardLine)
            yardsToGo = newYardsToGo
            clockTask?.cancel()
            runTask?.cancel()
            // Reset to 1st down but keep going
            down = 1

            withAnimation {
                playResultLabel = "FIRST DOWN!"
                playResultColor = Theme.brandCyan
                showPlayResult = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run {
                    showPlayResult = false
                    phase = .catchRoute
                    setupCatchPhase()
                    startClock()
                }
            }
        }
    }

    private func spawnFireworks() {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        fireworkPositions = (0..<40).map { _ in
            CGPoint(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height * 0.7)
            )
        }
    }

    // MARK: - Down Progression

    private func advanceDown(yardsGained yards: Int) {
        yardLine += yards
        yardsToGo = max(0, yardsToGo - yards)

        if yardsToGo <= 0 {
            // First down!
            down = 1
            yardsToGo = min(YARDS_TO_GO_INITIAL, 100 - yardLine)
        } else {
            down += 1
        }

        if down > MAX_DOWNS {
            // Turnover on downs
            phase = .turnover
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                await MainActor.run { phase = .result }
            }
            return
        }

        // Next play
        playClock = 40
        phase = .catchRoute
        setupCatchPhase()
        startClock()
    }

    // MARK: - Play Clock

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task {
            while playClock > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { playClock -= 1 }
            }
            // Clock expired — delay of game, loss of down
            await MainActor.run {
                if phase == .catchRoute {
                    handleIncompletionOrSack()
                }
            }
        }
    }

    // MARK: - Cleanup

    private func cancelAllTasks() {
        routeTask?.cancel()
        runTask?.cancel()
        clockTask?.cancel()
    }

    // MARK: - Rewards

    private func grantRewards(shards: Int) {
        guard !rewardGranted else { return }
        rewardGranted = true
        viewModel.profile.evolutionShards += shards
        let xpGain = min(XP_CAP_PER_SESSION, shards * 2)
        viewModel.profile.metrics.prqScore = min(100, viewModel.profile.metrics.prqScore + Double(xpGain) / 100.0)
    }
}
