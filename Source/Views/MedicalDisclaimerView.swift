import SwiftUI

/// Mandatory first-launch gate (Bonds Standard / Sovereign Launch 1.0.0).
/// Blocks all app chrome until the athlete acknowledges clinical-education scope — not medical diagnosis.
struct MedicalDisclaimerView: View {
    var onAccept: () -> Void

    @State private var acknowledged = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.07),
                    Color(red: 0.02, green: 0.03, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                    Text("Medical disclaimer")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Final Evolution Lab provides clinical movement education and athletic skill development. It is not a medical device and does not provide medical diagnosis, treatment, or rehabilitation plans.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                        Text("If you have pain, injury, cardiopulmonary concerns, or any condition that requires professional care, consult a licensed physician or qualified clinician before using training tools in this app.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.78))
                        Text("Biometric readouts, PRQ scores, SFMA-inspired screens, and Unreal overlays are educational visualizations — not substitutes for in-person clinical examination.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.78))
                        Text("By continuing, you confirm you understand these limits and accept responsibility for how you use the Lab.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.brandCyan.opacity(0.95))
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)

                Toggle(isOn: $acknowledged) {
                    Text("I have read and understand: Final Evolution is not medical advice.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .tint(Theme.brandCyan)
                .padding(.vertical, 12)

                Button {
                    guard acknowledged else { return }
                    onAccept()
                } label: {
                    Text("Continue to the Lab")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(acknowledged ? Theme.brandBlue : Theme.brandBlue.opacity(0.35))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!acknowledged)
                .accessibilityLabel("Continue to the Lab")
                .accessibilityHint("Requires accepting the medical disclaimer")
            }
            .padding(24)
        }
    }
}

#if DEBUG
#Preview {
    MedicalDisclaimerView(onAccept: {})
}
#endif
