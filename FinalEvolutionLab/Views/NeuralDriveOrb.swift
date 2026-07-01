import SwiftUI

struct NeuralDriveOrb: View {
    let value: Double      // 0–100

    @State private var rotation: Double = 0
    @State private var counterRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var innerGlow: Double = 0.4

    private var fraction: Double { min(max(value / 100.0, 0), 1) }

    // Color shifts blue → cyan → green as value rises
    private var orbColor: Color {
        if value < 40 { return Color(red: 0.25, green: 0.50, blue: 1.0) }
        if value < 70 { return Color(red: 0.10, green: 0.75, blue: 1.0) }
        return Color(red: 0.20, green: 1.00, blue: 0.60)
    }

    var body: some View {
        ZStack {
            // Outer ambient glow — brightness scales with value
            Circle()
                .fill(RadialGradient(
                    colors: [orbColor.opacity(fraction * 0.35), .clear],
                    center: .center, startRadius: 4, endRadius: 44))

            // Counter-rotating outer ring (thin dashed)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [orbColor.opacity(0.5), .clear, orbColor.opacity(0.5)],
                        center: .center),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                .scaleEffect(0.92)
                .rotationEffect(.degrees(counterRotation))

            // Filled arc showing value percentage
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(
                    AngularGradient(
                        colors: [orbColor.opacity(0.9), orbColor.opacity(0.4)],
                        center: .center),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Co-rotating middle ring
            ForEach(0..<2, id: \.self) { ring in
                Circle()
                    .stroke(orbColor.opacity(0.12 + Double(ring) * 0.08), lineWidth: 1)
                    .scaleEffect(0.56 + Double(ring) * 0.22)
                    .rotationEffect(.degrees(rotation + Double(ring) * 45))
            }

            // Orbiting particle dots (3 dots, phase offset)
            ForEach(0..<3, id: \.self) { i in
                let angle = (rotation * (1.0 + Double(i) * 0.3) + Double(i) * 120.0)
                let r: CGFloat = 14 + CGFloat(i) * 3
                Circle()
                    .fill(orbColor.opacity(0.5 + Double(i) * 0.15))
                    .frame(width: CGFloat(2 + i), height: CGFloat(2 + i))
                    .offset(x: r * CGFloat(cos(angle * .pi / 180)),
                            y: r * CGFloat(sin(angle * .pi / 180)))
            }

            // Core glow
            Circle()
                .fill(orbColor.opacity(innerGlow))
                .frame(width: 14, height: 14)
                .blur(radius: 5)
                .scaleEffect(pulseScale)

            // Core dot
            Circle()
                .fill(orbColor)
                .frame(width: 6, height: 6)
                .shadow(color: orbColor, radius: 8)
        }
        .frame(width: 52, height: 52)
        .onAppear {
            let speed = 6.0 + fraction * 4.0
            withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.linear(duration: speed * 0.65).repeatForever(autoreverses: false)) {
                counterRotation = -360
            }
            let pulseSpeed = max(0.8, 2.0 - fraction)
            withAnimation(.easeInOut(duration: pulseSpeed).repeatForever(autoreverses: true)) {
                pulseScale = 1.25
                innerGlow = 0.6 + fraction * 0.3
            }
        }
    }
}
