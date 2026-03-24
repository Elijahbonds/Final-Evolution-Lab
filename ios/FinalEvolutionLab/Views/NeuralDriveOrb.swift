import SwiftUI

struct NeuralDriveOrb: View {
    let value: Double
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.brandBlue.opacity(0.3),
                            Theme.brandBlue.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 40
                    )
                )

            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(
                        Theme.brandBlue.opacity(0.15 + Double(ring) * 0.1),
                        lineWidth: 1
                    )
                    .scaleEffect(0.5 + Double(ring) * 0.2)
                    .rotationEffect(.degrees(rotation + Double(ring) * 30))
            }

            Circle()
                .fill(Theme.brandBlue.opacity(0.6))
                .frame(width: 16, height: 16)
                .blur(radius: 4)

            Circle()
                .fill(Theme.brandBlue)
                .frame(width: 8, height: 8)
                .shadow(color: Theme.brandBlue, radius: 8)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
