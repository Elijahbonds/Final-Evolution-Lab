import SwiftUI
import UIKit
import OSLog

struct UnrealContainerView: View {
    var onExit: () -> Void = {}

    @State private var unrealManager = UnrealManager.shared

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "UnrealContainer")

    var body: some View {
        ZStack {
            if unrealManager.isUnrealActive && unrealManager.isUnrealLoaded {
                if unrealManager.unrealView != nil {
                    UnrealContainerRepresentable()
                        .ignoresSafeArea()
                } else {
                    embeddingUnavailablePanel(message: "Arena runtime loaded but did not expose a view (rootView). Check the embedded UnrealFramework export.")
                }
            } else if unrealManager.isUnrealActive && !unrealManager.isUnrealLoaded && unrealManager.isFrameworkPresent {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Theme.brandCyan)
                        .scaleEffect(1.2)
                    Text("LOADING ARENA RUNTIME…")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.deepBlack)
            } else {
                placeholder
            }

            VStack {
                HStack {
                    Spacer()
                    if unrealManager.isUnrealActive {
                        Button {
                            withAnimation(.spring(duration: 0.35)) {
                                unrealManager.isUnrealActive = false
                                onExit()
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
        .onAppear {
            if unrealManager.isUnrealLoaded {
                let hasRoot = unrealManager.unrealView != nil
                Self.log.notice("Unreal loaded — rootView present: \(hasRoot, privacy: .public)")
            }
        }
    }

    private func embeddingUnavailablePanel(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("RUNTIME VIEW MISSING")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(2)
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("CLOSE") {
                unrealManager.isUnrealActive = false
                onExit()
            }
            .font(.system(.subheadline, design: .monospaced, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Theme.brandCyan)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.deepBlack)
    }

    private var placeholder: some View {
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
                Text("UNREAL ENGINE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)

                Text(unrealManager.isFrameworkPresent ? "Tap to activate the Unreal runtime" : "UnrealFramework.framework not embedded yet")
                    .font(.system(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                guard unrealManager.isFrameworkPresent else { return }
                withAnimation(.spring(duration: 0.4)) {
                    unrealManager.isUnrealActive = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("START UNREAL")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(unrealManager.isFrameworkPresent ? Theme.brandCyan : Theme.brandCyan.opacity(0.25))
                .clipShape(Capsule())
            }
            .disabled(!unrealManager.isFrameworkPresent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.deepBlack)
    }
}

struct UnrealContainerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UnrealHostViewController {
        UnrealHostViewController()
    }

    func updateUIViewController(_ uiViewController: UnrealHostViewController, context: Context) {}
}

final class UnrealHostViewController: UIViewController {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "UnrealHost")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        if let unrealView = UnrealManager.shared.unrealView {
            unrealView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(unrealView)
            NSLayoutConstraint.activate([
                unrealView.topAnchor.constraint(equalTo: view.topAnchor),
                unrealView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                unrealView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                unrealView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        } else {
            Self.log.error("UnrealHostViewController: unrealView is nil — embed rootView in UnrealFramework.")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UnrealManager.shared.containerViewForScreenshot = view
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if UnrealManager.shared.containerViewForScreenshot === view {
            UnrealManager.shared.containerViewForScreenshot = nil
        }
    }
}
