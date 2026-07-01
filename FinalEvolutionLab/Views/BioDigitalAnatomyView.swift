import SwiftUI
import SceneKit

struct BioDigitalAnatomyView: View {
    let moduleId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = AnatomyEducationService.shared
    
    @State private var loading = true
    @State private var receipt: String?
    @State private var progress: Double = 0.0
    @State private var isSubmitting = false
    @State private var completionSuccess = false
    @State private var errorMessage: String?
    
    private let targetSeconds: Double = 3.5 // Slightly above 3s to guarantee compliance
    @State private var timer: Timer?
    @State private var elapsedSeconds: Double = 0.0
    
    var body: some View {
        ZStack {
            Theme.deepBlack
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("BIO-DIGITAL ANATOMY STUDY")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.brandCyan)
                                .tracking(2)
                            FELPreviewLabel(text: FELPremiumCopy.Preview.sceneKitStub)
                        }
                        Text(moduleTitle)
                            .font(.system(.title2, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                if loading {
                    Spacer()
                    ProgressView()
                        .tint(Theme.brandCyan)
                    Text("SYNCHRONIZING BIO-DIGITAL LINK...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 8)
                    Spacer()
                } else if completionSuccess {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Theme.brandCyan)
                        Text("OVERLAY OVERRIDE MASTERED")
                            .font(.system(.headline, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                        Text("Anatomical patterns successfully mapped to profile neural net.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("DONE")
                                .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Capsule().fill(Theme.brandCyan))
                                .padding(.horizontal, 48)
                                .padding(.top, 16)
                        }
                    }
                    Spacer()
                } else {
                    // 3D Scene
                    ZStack(alignment: .topTrailing) {
                        BioDigitalSceneContainer()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.cardBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                        
                        // Sci-fi Hud Overlays
                        VStack(alignment: .trailing, spacing: 8) {
                            HudRow(label: "FPS", value: "60.0")
                            HudRow(label: "RENDER", value: "SCN_METAL")
                            HudRow(label: "FOV", value: "60°")
                            HudRow(label: "MESH", value: "HIFI_KINETIC")
                        }
                        .padding(16)
                    }
                    .frame(height: 320)
                    .padding(.horizontal)
                    
                    // Controls / Telemetry info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BIO-FEEDBACK TELEMETRY")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.elitePurple)
                            .tracking(2)
                        
                        HStack(spacing: 12) {
                            TelemetryPill(label: "PELVIS ROTATION", value: "0.24 rad")
                            TelemetryPill(label: "FASCIAL TENSION", value: "High")
                            TelemetryPill(label: "NEURAL LATENCY", value: "4.2 ms")
                        }
                        
                        Text(moduleDescription)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(.vertical, 8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Progress and Mastery Submission
                    VStack(spacing: 12) {
                        // Progress bar
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("INTEGRATING OVERLAY...")
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                Spacer()
                                Text(String(format: "%.0f%%", min(1.0, progress) * 100))
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                                    .foregroundStyle(Theme.brandCyan)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.brandCyan, Theme.brandBlue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(min(1.0, progress)), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.horizontal, 24)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button {
                            Task {
                                await completeModule()
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.black)
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 8)
                                }
                                Text("REGISTER OVERLAY MASTERY")
                                    .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Capsule()
                                    .fill(
                                        progress >= 1.0
                                        ? LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                    )
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom)
                        }
                        .disabled(progress < 1.0 || isSubmitting)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await startModule()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var moduleTitle: String {
        switch moduleId {
        case "skeletal_basics": return "SKELETAL BASICS"
        case "muscular_chains": return "MUSCULAR CHAINS"
        case "kinetic_chain_pillars": return "KINETIC CHAIN PILLARS"
        case "neural_priming": return "NEURAL PRIMING"
        default: return moduleId.uppercased().replacingOccurrences(of: "_", with: " ")
        }
    }
    
    private var moduleDescription: String {
        switch moduleId {
        case "skeletal_basics":
            return "Identify joints of rotation and center of mass alignment. Key markers are set at the calcaneus, femoral epicondyle, and sacral center."
        case "muscular_chains":
            return "Track continuous fascia lines including the posterior oblique sling. Torque transfers through the gluteus maximus to opposite latissimus dorsi."
        case "kinetic_chain_pillars":
            return "Monitor structural loading vectors. Ensure pelvic tilt remains neutral under ground reaction forces."
        case "neural_priming":
            return "Evaluate motor unit synchronization. High HRV indicators suggest readiness for optimal velocity profile integration."
        default:
            return "Scan and synchronize live biomechanical markers for the current module."
        }
    }
    
    private func startModule() async {
        loading = true
        errorMessage = nil
        do {
            receipt = try await service.beginModule(moduleId: moduleId)
            loading = false
            
            // Start the dwell timer
            elapsedSeconds = 0.0
            progress = 0.0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                elapsedSeconds += 0.1
                progress = elapsedSeconds / targetSeconds
                if elapsedSeconds >= targetSeconds {
                    progress = 1.0
                    timer?.invalidate()
                }
            }
        } catch {
            errorMessage = "Failed to begin module: \(error.localizedDescription)"
            loading = false
        }
    }
    
    private func completeModule() async {
        guard let receipt = receipt else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await service.completeModule(moduleId: moduleId, receipt: receipt)
            isSubmitting = false
            completionSuccess = true
            FelToastCenter.shared.show("Module mastered successfully!", isError: false)
        } catch {
            errorMessage = "Failed to complete module: \(error.localizedDescription)"
            isSubmitting = false
        }
    }
}

// SceneKit View for 3D model
private struct BioDigitalSceneContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = GameSceneFactory.buildDrawingInTutorialScene()
        v.autoenablesDefaultLighting = true
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.allowsCameraControl = true
        
        // Spin the model slowly
        if let avatar = v.scene?.rootNode.childNode(withName: "drawingAvatar", recursively: false) {
            let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 1.0, z: 0, duration: 8.0))
            avatar.runAction(spin)
        }
        
        return v
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

private struct HudRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.6)))
    }
}

private struct TelemetryPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }
}
