import SwiftUI

/// Lightweight global toasts for sync / feed errors (Phase 7).
@MainActor
final class FelToastCenter: ObservableObject {
    static let shared = FelToastCenter()

    @Published var message: String?
    @Published var isError: Bool = false

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, isError: Bool = false, durationNanoseconds: UInt64 = 3_500_000_000) {
        self.message = message
        self.isError = isError
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: durationNanoseconds)
            self.message = nil
        }
    }
}

struct FelToastOverlay: View {
    @ObservedObject private var toast = FelToastCenter.shared

    var body: some View {
        Group {
            if let text = toast.message {
                HStack(spacing: 10) {
                    Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(toast.isError ? Color.orange : Theme.brandCyan)
                    Text(text)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder((toast.isError ? Color.orange : Theme.brandCyan).opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: toast.message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}
