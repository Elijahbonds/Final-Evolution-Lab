import SwiftUI
import UIKit

nonisolated enum UnityMode: String, Sendable {
    case freestyleDunk
    case training
    case arcade
}

struct UnityContainerView: View {
    var mode: UnityMode = .training
    @State private var unityManager = UnityManager.shared

    var body: some View {
        ZStack {
            if unityManager.isUnityActive && unityManager.isUnityLoaded {
                UnityContainerRepresentable()
                    .ignoresSafeArea()
            } else {
                unityPlaceholder
            }

            VStack {
                HStack {
                    Spacer()
                    if unityManager.isUnityActive {
                        Button {
                            withAnimation(.spring(duration: 0.35)) {
                                unityManager.isUnityActive = false
                            }
                        } label: {
                            Image(systemName: "power")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.neonGreen)
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

    private var unityPlaceholder: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Theme.neonGreen.opacity(0.08))
                    .frame(width: 120, height: 120)

                Circle()
                    .strokeBorder(Theme.neonGreen.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)

                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Theme.neonGreen)
            }

            VStack(spacing: 8) {
                Text("TRAINING ENGINE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.neonGreen)
                    .tracking(4)

                Text("Tap to activate the Unity runtime")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.spring(duration: 0.4)) {
                    unityManager.isUnityActive = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("START TRAINING")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Theme.neonGreen)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.slateBackground)
    }
}

struct UnityContainerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UnityHostViewController {
        UnityHostViewController()
    }

    func updateUIViewController(_ uiViewController: UnityHostViewController, context: Context) {}
}

class UnityHostViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        UnityManager.shared.containerViewForScreenshot = view

        if let unityView = UnityManager.shared.unityView {
            unityView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(unityView)
            NSLayoutConstraint.activate([
                unityView.topAnchor.constraint(equalTo: view.topAnchor),
                unityView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                unityView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                unityView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if UnityManager.shared.containerViewForScreenshot === view {
            UnityManager.shared.containerViewForScreenshot = nil
        }
    }
}
