import SwiftUI

/// Shown once when entering Brain Brawl. Explains first-correct-answer-wins.
struct FirstTimeBrainBrawlOverlay: View {
    var accentColor: Color = Theme.brandBlue
    var onDismiss: () -> Void

    @State private var appeared = false

    private static let hasSeenKey = "fel_brain_brawl_tutorial_seen"

    static var hasSeen: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenKey) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Text("BRAIN BRAWL")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(accentColor)

                Text("Answer first to win the question. Five questions — highest score wins. Tap a choice to lock in your answer.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    dismiss()
                } label: {
                    Text("GOT IT")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(accentColor.opacity(0.35), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appeared = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Brain Brawl. Answer first to win the question. Five questions, highest score wins. Tap Got It to continue.")
    }

    private func dismiss() {
        Self.hasSeen = true
        withAnimation(.easeOut(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}
