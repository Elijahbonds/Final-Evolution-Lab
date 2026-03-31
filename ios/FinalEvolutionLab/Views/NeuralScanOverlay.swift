import SwiftUI

struct NeuralScanOverlay: View {
    let isActive: Bool

    @State private var scanLineY: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                    .opacity(isActive ? 0.7 : 0)

                if isActive {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Theme.brandCyan.opacity(0.4),
                                    Theme.brandBlue.opacity(0.6),
                                    Theme.brandCyan.opacity(0.4),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 4)
                        .blur(radius: 6)
                        .offset(y: scanLineY - geo.size.height / 2)
                        .onAppear {
                            scanLineY = -geo.size.height / 2
                            withAnimation(.easeInOut(duration: 0.6)) {
                                scanLineY = geo.size.height / 2
                            }
                        }

                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                            .symbolEffect(.pulse)

                        Text("NEURAL SCAN")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(4)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}
