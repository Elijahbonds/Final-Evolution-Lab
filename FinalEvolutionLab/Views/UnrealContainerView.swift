import SwiftUI
import UIKit

// Legacy container kept for compatibility — game modes now route directly to GamePlayView.
// This view is wired to the optional NexusBridge external rendering framework if present.
struct NexusContainerView: View {
    @State private var bridge = NexusBridge.shared

    var body: some View {
        ZStack {
            if bridge.isUnrealActive && bridge.isUnrealLoaded {
                NexusContainerRepresentable()
                    .ignoresSafeArea()
            } else if bridge.isUnrealActive && !bridge.isUnrealLoaded {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Theme.brandCyan)
                        .scaleEffect(1.2)
                    Text("LOADING NEXUS RUNTIME…")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.deepBlack)
            } else {
                nexusPlaceholder
            }

            VStack {
                HStack {
                    Spacer()
                    if bridge.isUnrealActive {
                        Button {
                            withAnimation(.spring(duration: 0.35)) {
                                bridge.isUnrealActive = false
                            }
                        } label: {
                            Image(systemName: "power")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.brandCyan)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                    }
                }
                Spacer()
            }
        }
    }

    private var nexusPlaceholder: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.brandCyan.opacity(0.08))
                    .frame(width: 120, height: 120)
                Circle()
                    .strokeBorder(Theme.brandCyan.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.brandCyan)
            }

            VStack(spacing: 6) {
                Text("NEXUS ENGINE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)
                Text("External rendering framework not embedded")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.deepBlack)
    }
}

// Backward-compat alias so any stale references compile.
typealias UnrealContainerView = NexusContainerView

struct NexusContainerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> NexusHostViewController {
        NexusHostViewController()
    }
    func updateUIViewController(_ uiViewController: NexusHostViewController, context: Context) {}
}

final class NexusHostViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        if let nexusView = NexusBridge.shared.unrealView {
            nexusView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(nexusView)
            NSLayoutConstraint.activate([
                nexusView.topAnchor.constraint(equalTo: view.topAnchor),
                nexusView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                nexusView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                nexusView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }
    }
}
