import SwiftUI

struct PS2ControllerShellView: View {
    var showShoulders: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    Spacer()
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 36,
                        bottomTrailingRadius: 36,
                        topTrailingRadius: 20
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.22),
                                Color(white: 0.14),
                                Color(white: 0.09)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 36,
                            bottomTrailingRadius: 36,
                            topTrailingRadius: 20
                        )
                        .stroke(Color(white: 0.04), lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 16, y: 4)
                    .frame(height: 160)
                }

                if showShoulders {
                    VStack {
                        Spacer()
                        HStack {
                            VStack(spacing: 2) {
                                shoulderButton(label: "L2")
                                shoulderButton(label: "L1")
                            }
                            .padding(.leading, 20)

                            Spacer()

                            VStack(spacing: 2) {
                                shoulderButton(label: "R2")
                                shoulderButton(label: "R1")
                            }
                            .padding(.trailing, 20)
                        }
                        .padding(.bottom, 140)
                    }
                }

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        analogStickWell
                            .padding(.leading, 24)
                            .padding(.bottom, 24)

                        Spacer()

                        analogStickWell
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        selectStartButtons
                        Spacer()
                    }
                    .padding(.bottom, 12)
                }

                VStack {
                    Spacer()
                    Text("DUALSHOCK\u{00AE}2")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.18))
                        .tracking(3)
                        .padding(.bottom, 4)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func shoulderButton(label: String) -> some View {
        Text(label)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.25))
            .frame(width: 36, height: 14)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 4
                )
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.26), Color(white: 0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 4
                )
                .stroke(Color(white: 0.10), lineWidth: 0.5)
            )
    }

    private var analogStickWell: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.14), Color(white: 0.07)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 22
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.05), lineWidth: 2)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.18), Color(white: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.22), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
    }

    private var selectStartButtons: some View {
        HStack(spacing: 16) {
            Capsule()
                .fill(Color(white: 0.12))
                .frame(width: 24, height: 8)
                .overlay(
                    Capsule()
                        .stroke(Color(white: 0.08), lineWidth: 0.5)
                )

            Circle()
                .fill(Color(white: 0.10))
                .frame(width: 6, height: 6)

            Capsule()
                .fill(Color(white: 0.12))
                .frame(width: 24, height: 8)
                .overlay(
                    Capsule()
                        .stroke(Color(white: 0.08), lineWidth: 0.5)
                )
        }
    }
}
