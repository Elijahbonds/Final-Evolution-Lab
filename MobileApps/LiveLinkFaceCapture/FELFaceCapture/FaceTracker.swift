// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: ARKit Face Tracker - Captures 52 ARKit blend shapes at 60 FPS

import Foundation
import ARKit
import Combine

/// Manages ARKit face tracking session and provides blend shape data.
class FaceTracker: NSObject, ObservableObject, ARSessionDelegate {
    
    // MARK: - Published Properties
    
    @Published var isTracking: Bool = false
    @Published var currentBlendShapes: [String: Float] = [:]
    @Published var currentFPS: Int = 0
    @Published var trackingQuality: String = "None"
    @Published var isCalibrated: Bool = false
    
    // MARK: - Internal State
    
    private var arSession: ARSession?
    private var frameCount: Int = 0
    private var lastFPSUpdate: Date = Date()
    private var neutralPoseOffsets: [String: Float] = [:]
    private var smoothingAlpha: Float = 0.15
    private var previousBlendShapes: [String: Float] = [:]
    
    /// Callback for streaming blend shapes to Live Link client.
    var onBlendShapesUpdated: (([String: Float]) -> Void)?
    
    // MARK: - ARKit Blend Shape Names (52 total)
    
    static let arkitBlendShapeNames: [ARFaceAnchor.BlendShapeLocation] = [
        // Eyes (14)
        .eyeBlinkLeft, .eyeLookDownLeft, .eyeLookInLeft, .eyeLookOutLeft,
        .eyeLookUpLeft, .eyeSquintLeft, .eyeWideLeft,
        .eyeBlinkRight, .eyeLookDownRight, .eyeLookInRight, .eyeLookOutRight,
        .eyeLookUpRight, .eyeSquintRight, .eyeWideRight,
        // Jaw (4)
        .jawForward, .jawLeft, .jawRight, .jawOpen,
        // Mouth (23)
        .mouthClose, .mouthFunnel, .mouthPucker,
        .mouthLeft, .mouthRight,
        .mouthSmileLeft, .mouthSmileRight,
        .mouthFrownLeft, .mouthFrownRight,
        .mouthDimpleLeft, .mouthDimpleRight,
        .mouthStretchLeft, .mouthStretchRight,
        .mouthRollLower, .mouthRollUpper,
        .mouthShrugLower, .mouthShrugUpper,
        .mouthPressLeft, .mouthPressRight,
        .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthUpperUpLeft, .mouthUpperUpRight,
        // Brow (5)
        .browDownLeft, .browDownRight,
        .browInnerUp, .browOuterUpLeft, .browOuterUpRight,
        // Cheek (3)
        .cheekPuff, .cheekSquintLeft, .cheekSquintRight,
        // Nose (2)
        .noseSneerLeft, .noseSneerRight,
        // Tongue (1)
        .tongueOut
    ]
    
    // MARK: - Lifecycle
    
    override init() {
        super.init()
    }
    
    deinit {
        stopTracking()
    }
    
    // MARK: - Public API
    
    /// Check if ARKit face tracking is supported on this device.
    static var isFaceTrackingSupported: Bool {
        return ARFaceTrackingConfiguration.isSupported
    }
    
    /// Start the ARKit face tracking session.
    func startTracking() {
        guard FaceTracker.isFaceTrackingSupported else {
            print("[FELFaceTracker] ARKit face tracking not supported on this device.")
            return
        }
        
        let session = ARSession()
        session.delegate = self
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isWorldTrackingEnabled = false
        
        // Request 60 FPS
        if #available(iOS 16.0, *) {
            configuration.videoHDRAllowed = false
        }
        
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arSession = session
        
        DispatchQueue.main.async {
            self.isTracking = true
        }
        
        print("[FELFaceTracker] Face tracking started.")
    }
    
    /// Stop the ARKit face tracking session.
    func stopTracking() {
        arSession?.pause()
        arSession = nil
        
        DispatchQueue.main.async {
            self.isTracking = false
            self.currentBlendShapes = [:]
            self.currentFPS = 0
            self.trackingQuality = "None"
        }
        
        print("[FELFaceTracker] Face tracking stopped.")
    }
    
    /// Capture the current face as neutral pose for calibration.
    func captureNeutralPose() {
        neutralPoseOffsets = currentBlendShapes
        isCalibrated = true
        print("[FELFaceTracker] Neutral pose captured with \(neutralPoseOffsets.count) offsets.")
    }
    
    /// Reset calibration to defaults.
    func resetCalibration() {
        neutralPoseOffsets = [:]
        isCalibrated = false
        print("[FELFaceTracker] Calibration reset.")
    }
    
    /// Set the smoothing factor (0 = no smoothing, 1 = max smoothing).
    func setSmoothingAlpha(_ alpha: Float) {
        smoothingAlpha = max(0, min(1, alpha))
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }
        
        // Extract blend shapes
        var blendShapes: [String: Float] = [:]
        
        for location in FaceTracker.arkitBlendShapeNames {
            if let value = faceAnchor.blendShapes[location] {
                var floatValue = value.floatValue
                let name = location.rawValue
                
                // Apply neutral pose calibration offset
                if let offset = neutralPoseOffsets[name] {
                    floatValue = max(0, min(1, floatValue - offset))
                }
                
                // Apply temporal smoothing
                if let prevValue = previousBlendShapes[name] {
                    floatValue = prevValue + (floatValue - prevValue) * (1.0 - smoothingAlpha)
                }
                
                blendShapes[name] = floatValue
            }
        }
        
        previousBlendShapes = blendShapes
        
        // Update FPS counter
        frameCount += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSUpdate)
        if elapsed >= 1.0 {
            let fps = Int(Double(frameCount) / elapsed)
            DispatchQueue.main.async {
                self.currentFPS = fps
            }
            frameCount = 0
            lastFPSUpdate = now
        }
        
        // Update tracking quality
        let quality: String
        if faceAnchor.isTracked {
            quality = "High"
        } else {
            quality = "Limited"
        }
        
        // Update published properties on main thread
        DispatchQueue.main.async {
            self.currentBlendShapes = blendShapes
            self.trackingQuality = quality
        }
        
        // Notify Live Link client
        onBlendShapesUpdated?(blendShapes)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[FELFaceTracker] ARSession failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isTracking = false
            self.trackingQuality = "Error"
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("[FELFaceTracker] ARSession interrupted.")
        DispatchQueue.main.async {
            self.trackingQuality = "Interrupted"
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("[FELFaceTracker] ARSession interruption ended.")
    }
}
