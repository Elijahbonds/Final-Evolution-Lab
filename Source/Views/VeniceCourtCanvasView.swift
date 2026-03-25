import SwiftUI

/// Simple Venice Beach court canvas for Head to Head / 3v3: hoop + shooter silhouette reacting to commit/contest.
struct VeniceCourtCanvasView: View {
    let accentColor: Color
    let showContestWindow: Bool
    let contestDecided: Bool?
    /// `nil` = pre-shot; after commit maps from PRQ feedback strings.
    var shotOutcome: ShotOutcome?

    enum ShotOutcome: Equatable {
        case bucket
        case good
        case miss
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.08, blue: 0.12),
                            Color(red: 0.01, green: 0.14, blue: 0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.35), lineWidth: 1)
                )

            // Baseline + three-point arc hint
            courtLines

            shotBall

            HStack {
                shooter
                    .offset(y: shotOutcome != nil ? -6 : 0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: shotOutcome)

                Spacer()

                hoop
                    .overlay(alignment: .topTrailing) {
                        if showContestWindow {
                            Text(contestLabel)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(contestColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.5))
                                )
                                .padding(8)
                                .transition(.opacity)
                        }
                    }
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 248)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var shotBall: some View {
        if let o = shotOutcome {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let ballX: CGFloat = {
                    switch o {
                    case .bucket: return w * 0.78
                    case .good: return w * 0.68
                    case .miss: return w * 0.52
                    }
                }()
                let ballY: CGFloat = {
                    switch o {
                    case .bucket: return h * 0.42
                    case .good: return h * 0.48
                    case .miss: return h * 0.55
                    }
                }()
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.95), Color.orange.opacity(0.5)],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 1,
                            endRadius: 8
                        )
                    )
                    .frame(width: 14, height: 14)
                    .position(x: ballX, y: ballY)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var contestLabel: String {
        guard let decided = contestDecided else { return "CONTEST?" }
        return decided ? "CONTESTED" : "CLEAN LOOK"
    }

    private var contestColor: Color {
        guard let decided = contestDecided else { return Color.yellow }
        return decided ? Color.red : Color.green
    }

    private var courtLines: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: w * 0.9, height: 1.2)
                    .position(x: w / 2, y: h * 0.78)
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    .frame(width: w * 0.44, height: w * 0.44)
                    .position(x: w * 0.72, y: h * 0.78)
            }
        }
    }

    private var shooter: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 10, height: 10)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.9))
                .frame(width: 12, height: 24)
            Capsule()
                .fill(Color.white.opacity(0.7))
                .frame(width: 3, height: 18)
        }
    }

    private var hoop: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(hoopRimColor.opacity(0.95), lineWidth: shotOutcome == .bucket ? 2.2 : 1.5)
                .shadow(color: (shotOutcome == .bucket ? Theme.foundationGreen : accentColor).opacity(shotOutcome != nil ? 0.45 : 0), radius: shotOutcome == .bucket ? 10 : 6)
            Capsule()
                .stroke(accentColor.opacity(shotOutcome == .miss ? 0.35 : 1), lineWidth: 2)
                .frame(width: 26, height: 8)
        }
        .animation(.easeOut(duration: 0.25), value: shotOutcome)
    }

    private var hoopRimColor: Color {
        switch shotOutcome {
        case .bucket: return Theme.foundationGreen
        case .good: return Color.orange
        case .miss: return Color.white.opacity(0.5)
        case .none: return Color.white.opacity(0.8)
        }
    }
}

