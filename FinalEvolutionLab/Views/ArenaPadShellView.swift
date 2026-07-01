import SwiftUI

struct ArenaPadShellView: View {
    var showShoulders: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    Spacer()
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 28,
                        bottomTrailingRadius: 28,
                        topTrailingRadius: 16
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.20).opacity(0.85),
                                Color(white: 0.12).opacity(0.9),
                                Color(white: 0.08).opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 28,
                            bottomTrailingRadius: 28,
                            topTrailingRadius: 16
                        )
                        .stroke(Color(white: 0.05), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 3)
                    .frame(height: geo.size.height)
                }

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        analogStickWell
                            .padding(.leading, 22)
                            .padding(.bottom, 18)

                        Spacer()

                        analogStickWell
                            .padding(.trailing, 22)
                            .padding(.bottom, 18)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        selectStartButtons
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }

                VStack {
                    Spacer()
                    Text("DUALSHOCK\u{00AE}2")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.15))
                        .tracking(3)
                        .padding(.bottom, 2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var analogStickWell: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.14).opacity(0.7), Color(white: 0.07).opacity(0.7)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 18
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.05), lineWidth: 1.5)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.18), Color(white: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
    }

    private var selectStartButtons: some View {
        HStack(spacing: 14) {
            Capsule()
                .fill(Color(white: 0.12).opacity(0.6))
                .frame(width: 20, height: 6)

            Circle()
                .fill(Color(white: 0.10).opacity(0.5))
                .frame(width: 5, height: 5)

            Capsule()
                .fill(Color(white: 0.12).opacity(0.6))
                .frame(width: 20, height: 6)
        }
    }
}
