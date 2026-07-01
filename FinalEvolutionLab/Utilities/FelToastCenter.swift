import Combine
import SwiftUI

/// Lightweight global toasts for sync / feed / receipt errors (Phase 7 + Premium QA).
@MainActor
final class FelToastCenter: ObservableObject {
    static let shared = FelToastCenter()

    @Published var message: String?
    @Published var isError: Bool = false
    @Published var showsRetry: Bool = false

    private var dismissTask: Task<Void, Never>?
    private var retryHandler: (() -> Void)?

    private init() {}

    func show(
        _ message: String,
        isError: Bool = false,
        retry: (() -> Void)? = nil,
        durationNanoseconds: UInt64 = 3_500_000_000
    ) {
        self.message = message
        self.isError = isError
        self.showsRetry = retry != nil
        self.retryHandler = retry
        dismissTask?.cancel()
        let duration = retry != nil ? max(durationNanoseconds, 6_000_000_000) : durationNanoseconds
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: duration)
            self.clear()
        }
    }

    func retryTapped() {
        let handler = retryHandler
        clear()
        handler?()
    }

    private func clear() {
        message = nil
        showsRetry = false
        retryHandler = nil
    }
}

struct FelToastOverlay: View {
    @ObservedObject private var toast = FelToastCenter.shared

    var body: some View {
        Group {
            if let text = toast.message {
                VStack(spacing: FELSpacing.sm) {
                    HStack(spacing: 10) {
                        Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(toast.isError ? Color.orange : Theme.brandCyan)
                        Text(text)
                            .font(FELTypography.caption(13).weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }

                    if toast.showsRetry {
                        Button {
                            toast.retryTapped()
                        } label: {
                            Text("RETRY")
                                .font(FELTypography.mono(11, weight: .black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, FELSpacing.lg)
                                .padding(.vertical, FELSpacing.xs)
                                .background(Theme.brandCyan)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder((toast.isError ? Color.orange : Theme.brandCyan).opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, FELSpacing.md)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: toast.message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(toast.showsRetry)
    }
}
