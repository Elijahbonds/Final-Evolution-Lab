import SwiftUI

struct PS2ControllerShellView: View {
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
                                Color(white: 0.22).opacity(0.42),
                                Color(white: 0.14).opacity(0.38),
                                Color(white: 0.10).opacity(0.35)
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
                        .stroke(Color(white: 0.12).opacity(0.5), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
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
                        .foregroundStyle(.white.opacity(0.25))
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
                        colors: [Color(white: 0.18).opacity(0.4), Color(white: 0.10).opacity(0.35)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 18
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.12).opacity(0.45), lineWidth: 1.5)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.32).opacity(0.5), Color(white: 0.20).opacity(0.45), Color(white: 0.16).opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.22).opacity(0.6), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
    }

    private var selectStartButtons: some View {
        HStack(spacing: 14) {
            Capsule()
                .fill(Color(white: 0.14).opacity(0.4))
                .frame(width: 20, height: 6)

            Circle()
                .fill(Color(white: 0.12).opacity(0.35))
                .frame(width: 5, height: 5)

            Capsule()
                .fill(Color(white: 0.14).opacity(0.4))
                .frame(width: 20, height: 6)
        }
    }
}
