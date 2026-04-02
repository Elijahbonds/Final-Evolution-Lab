// UE5GameContainerView.swift
// SwiftUI view that hosts the UE5 Metal rendering view.
// Falls back to a placeholder when UE5 framework is not embedded.

import SwiftUI
import UIKit

/// SwiftUI wrapper for the UE5 game rendering view
struct UE5GameContainerView: UIViewControllerRepresentable {
    let gameModeId: String
    let onExit: () -> Void
    let onScoreUpdate: (Int) -> Void
    
    func makeUIViewController(context: Context) -> UE5GameViewController {
        let vc = UE5GameViewController()
        vc.gameModeId = gameModeId
        vc.onExit = onExit
        vc.onScoreUpdate = onScoreUpdate
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UE5GameViewController, context: Context) {
        // Update if game mode changes
    }
}

/// UIKit view controller that hosts the UE5 Metal rendering view
class UE5GameViewController: UIViewController {
    var gameModeId: String = "basketball_h2h"
    var onExit: (() -> Void)?
    var onScoreUpdate: ((Int) -> Void)?
    
    private var ue5View: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        let bridge = UE5Bridge.shared
        
        if bridge.isAvailable {
            setupUE5View(bridge: bridge)
        } else {
            setupFallbackView()
        }
    }
    
    private func setupUE5View(bridge: UE5BridgeProtocol) {
        guard let metalView = bridge.createGameView() else {
            setupFallbackView()
            return
        }
        
        metalView.frame = view.bounds
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(metalView)
        ue5View = metalView
        
        // Set up callbacks
        var mutableBridge = bridge
        mutableBridge.onScoreUpdate = { [weak self] score in
            DispatchQueue.main.async {
                self?.onScoreUpdate?(score)
            }
        }
        mutableBridge.onModeComplete = { [weak self] modeId, finalScore in
            DispatchQueue.main.async {
                self?.onScoreUpdate?(finalScore)
                self?.onExit?()
            }
        }
        
        // Launch the game mode
        bridge.launchMode(gameModeId)
    }
    
    private func setupFallbackView() {
        let label = UILabel()
        label.text = "UE5 engine not embedded.\nUsing SceneKit fallback."
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.frame = view.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(label)
        
        // The app's GamePlayView already has SceneKit rendering
        // This controller is only used when explicitly requesting UE5
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UE5Bridge.shared.exitMode()
    }
    
    deinit {
        ue5View?.removeFromSuperview()
    }
}
