import SwiftUI
import UIKit

/// Hosts the Unreal Engine iOS Metal surface (or placeholder until the native UE view is attached). Place this **last** in a `ZStack` so it draws above SwiftUI fallbacks.
/// **Simulator:** skips the Metal host path (local Xcode / CI); use a device build for embedded Unreal.
struct UFELUnrealViewportContainer: View {
    @EnvironmentObject private var runtime: UFELUnrealOverlayRuntime

    var body: some View {
        #if targetEnvironment(simulator)
        FELUnrealSimulatorViewportPlaceholder(isReady: runtime.bIsUnrealReady)
            .background(Color.clear)
            .ignoresSafeArea()
            .accessibilityLabel("Unreal viewport placeholder simulator")
            .allowsHitTesting(false)
            .zIndex(1000)
        #else
        FELUnrealMetalHostViewRepresentable(isReady: runtime.bIsUnrealReady)
            .background(Color.clear)
            .ignoresSafeArea()
            .accessibilityLabel("Unreal three D viewport")
            .allowsHitTesting(runtime.bIsUnrealReady)
            .zIndex(1000)
        #endif
    }
}

#if targetEnvironment(simulator)
private struct FELUnrealSimulatorViewportPlaceholder: View {
    var isReady: Bool
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.04),
                    Color(red: 0.02, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(isReady ? 0.15 : 1)
            Text("Unreal viewport — device build")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.ultraThinMaterial, in: Capsule())
                .accessibilityHidden(true)
        }
    }
}
#endif

// MARK: - UIKit host (tagged for future UE view injection)

private enum FELUnrealViewportHost {
    static let viewTag = 9_001_337
}

/// When `isUnrealReady` is true, placeholder gradient is fully hidden so no dark layer sits above the embedded Metal / UE surface.
private final class FELUnrealHostView: UIView {
    private let gradient = CAGradientLayer()

    var isUnrealReady: Bool = false {
        didSet { updatePlaceholderForReadyState() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        tag = FELUnrealViewportHost.viewTag
        backgroundColor = .clear
        isOpaque = false
        gradient.name = "fel.unreal.viewport.placeholder"
        gradient.colors = [
            UIColor(white: 0.04, alpha: 1).cgColor,
            UIColor(red: 0.02, green: 0.05, blue: 0.12, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.2, y: 0)
        gradient.endPoint = CGPoint(x: 0.9, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    private func updatePlaceholderForReadyState() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.isHidden = isUnrealReady
        gradient.opacity = isUnrealReady ? 0 : 1
        backgroundColor = .clear
        alpha = 1
        CATransaction.commit()
        if isUnrealReady {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
}

private struct FELUnrealMetalHostViewRepresentable: UIViewRepresentable {
    var isReady: Bool

    func makeUIView(context: Context) -> FELUnrealHostView {
        let v = FELUnrealHostView()
        v.isUnrealReady = isReady
        return v
    }

    func updateUIView(_ uiView: FELUnrealHostView, context: Context) {
        uiView.isUnrealReady = isReady
        uiView.isUserInteractionEnabled = isReady
    }
}
