import SwiftUI

struct PS2ControllerShellView: View {
    var showShoulders: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.20),
                                    Color(white: 0.12),
                                    Color(white: 0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color(white: 0.05), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.55), radius: 14, y: 5)
                        .frame(height: 148)
                }

                VStack {
                    Spacer()
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                RadialGradient(
                                    colors: [Color(white: 0.16), Color(white: 0.09)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 20
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(white: 0.10), lineWidth: 2)
                            )
                            .frame(width: 40, height: 40)
                            .padding(.leading, 28)
                            .padding(.bottom, 92)
                        Spacer()
                    }
                }

                if showShoulders {
                    VStack {
                        Spacer()
                        HStack {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 5, bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0, topTrailingRadius: 5
                            )
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.24), Color(white: 0.15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 5, bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0, topTrailingRadius: 5
                                )
                                .stroke(Color(white: 0.10), lineWidth: 1)
                            )
                            .frame(width: 32, height: 14)
                            .padding(.leading, 68)

                            Spacer()

                            UnevenRoundedRectangle(
                                topLeadingRadius: 5, bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0, topTrailingRadius: 5
                            )
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.24), Color(white: 0.15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 5, bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0, topTrailingRadius: 5
                                )
                                .stroke(Color(white: 0.10), lineWidth: 1)
                            )
                            .frame(width: 32, height: 14)
                            .padding(.trailing, 68)
                        }
                        .padding(.bottom, 124)
                    }
                }

                VStack {
                    Spacer()
                    Text("DUALSHOCK 2")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(2)
                        .padding(.bottom, 10)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
