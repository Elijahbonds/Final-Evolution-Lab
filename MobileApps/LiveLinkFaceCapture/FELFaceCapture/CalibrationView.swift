// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: FEL Face Capture - Calibration UI

import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var faceTracker: FaceTracker
    @Environment(\.dismiss) var dismiss
    @State private var calibrationStep: CalibrationStep = .instructions
    @State private var countdownValue: Int = 3
    @State private var isCountingDown: Bool = false
    @State private var calibrationComplete: Bool = false
    
    enum CalibrationStep {
        case instructions
        case countdown
        case capturing
        case rangeOfMotion
        case complete
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                switch calibrationStep {
                case .instructions:
                    instructionsView
                case .countdown:
                    countdownView
                case .capturing:
                    capturingView
                case .rangeOfMotion:
                    rangeOfMotionView
                case .complete:
                    completeView
                }
            }
            .padding()
            .navigationTitle("Face Calibration")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Step Views
    
    var instructionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Face Calibration")
                .font(.title2.bold())
            
            Text("This process captures your neutral face to improve tracking accuracy.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                CalibrationInstructionRow(icon: "1.circle.fill", text: "Look directly at the camera")
                CalibrationInstructionRow(icon: "2.circle.fill", text: "Relax your face completely")
                CalibrationInstructionRow(icon: "3.circle.fill", text: "Hold still for 3 seconds")
                CalibrationInstructionRow(icon: "4.circle.fill", text: "Test range of motion")
            }
            .padding()
            
            Button(action: {
                calibrationStep = .countdown
                startCountdown()
            }) {
                Text("Begin Calibration")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            if faceTracker.isCalibrated {
                Button(action: {
                    faceTracker.resetCalibration()
                }) {
                    Text("Reset Existing Calibration")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    var countdownView: some View {
        VStack(spacing: 20) {
            Text("Hold Still")
                .font(.title2)
            
            Text("\(countdownValue)")
                .font(.system(size: 100, weight: .bold))
                .foregroundColor(.blue)
            
            Text("Keep your face relaxed and neutral")
                .foregroundColor(.secondary)
        }
    }
    
    var capturingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
            
            Text("Capturing Neutral Pose...")
                .font(.title2)
            
            Text("\(faceTracker.currentBlendShapes.count) blend shapes detected")
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Capture neutral pose after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                faceTracker.captureNeutralPose()
                calibrationStep = .rangeOfMotion
            }
        }
    }
    
    var rangeOfMotionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Range of Motion Test")
                .font(.title2.bold())
            
            Text("Make these expressions to test calibration:")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                ExpressionTestRow(expression: "Big Smile", value: faceTracker.currentBlendShapes["mouthSmileLeft"] ?? 0)
                ExpressionTestRow(expression: "Open Mouth", value: faceTracker.currentBlendShapes["jawOpen"] ?? 0)
                ExpressionTestRow(expression: "Raise Eyebrows", value: faceTracker.currentBlendShapes["browInnerUp"] ?? 0)
                ExpressionTestRow(expression: "Blink Eyes", value: faceTracker.currentBlendShapes["eyeBlinkLeft"] ?? 0)
                ExpressionTestRow(expression: "Puff Cheeks", value: faceTracker.currentBlendShapes["cheekPuff"] ?? 0)
            }
            .padding()
            
            Button(action: {
                calibrationStep = .complete
            }) {
                Text("Complete Calibration")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
        }
    }
    
    var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Calibration Complete!")
                .font(.title2.bold())
            
            Text("Your face is calibrated for optimal tracking. You can recalibrate anytime from settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helpers
    
    func startCountdown() {
        countdownValue = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdownValue -= 1
            if countdownValue <= 0 {
                timer.invalidate()
                calibrationStep = .capturing
            }
        }
    }
}

// MARK: - Subviews

struct CalibrationInstructionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
            Text(text)
                .font(.body)
        }
    }
}

struct ExpressionTestRow: View {
    let expression: String
    let value: Float
    
    var body: some View {
        HStack {
            Text(expression)
                .frame(width: 140, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(value > 0.5 ? Color.green : Color.orange)
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(height: 20)
            .cornerRadius(6)
            
            Image(systemName: value > 0.5 ? "checkmark.circle.fill" : "circle")
                .foregroundColor(value > 0.5 ? .green : .gray)
        }
    }
}
