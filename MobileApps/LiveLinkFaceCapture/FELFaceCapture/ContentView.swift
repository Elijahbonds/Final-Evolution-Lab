// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: FEL Face Capture - Main UI

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var faceTracker: FaceTracker
    @EnvironmentObject var connectionManager: LiveLinkConnectionManager
    @State private var showSettings = false
    @State private var showCalibration = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview background
                ARCameraPreview(faceTracker: faceTracker)
                    .ignoresSafeArea()
                
                // Overlay UI
                VStack {
                    // Status bar
                    HStack {
                        ConnectionStatusBadge(state: connectionManager.connectionState)
                        Spacer()
                        TrackingStatusBadge(isTracking: faceTracker.isTracking)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Face tracking visualization
                    if faceTracker.isTracking {
                        BlendShapeVisualization(blendShapes: faceTracker.currentBlendShapes)
                            .frame(height: 200)
                            .padding(.horizontal)
                    }
                    
                    // FPS indicator
                    HStack {
                        Text("\(faceTracker.currentFPS) FPS")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text("\(faceTracker.currentBlendShapes.count) shapes")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        Button(action: { showCalibration = true }) {
                            VStack {
                                Image(systemName: "face.smiling")
                                    .font(.title2)
                                Text("Calibrate")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(width: 80, height: 60)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(12)
                        }
                        
                        // Main connect/disconnect button
                        Button(action: {
                            if connectionManager.connectionState == .streaming {
                                connectionManager.disconnect()
                                faceTracker.stopTracking()
                            } else {
                                connectionManager.connect()
                                faceTracker.startTracking()
                            }
                        }) {
                            VStack {
                                Image(systemName: connectionManager.connectionState == .streaming
                                      ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44))
                                Text(connectionManager.connectionState == .streaming
                                     ? "Stop" : "Start")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(.white)
                            .frame(width: 100, height: 80)
                            .background(connectionManager.connectionState == .streaming
                                        ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                            .cornerRadius(16)
                        }
                        
                        Button(action: { showSettings = true }) {
                            VStack {
                                Image(systemName: "gearshape")
                                    .font(.title2)
                                Text("Settings")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(width: 80, height: 60)
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(connectionManager)
            }
            .sheet(isPresented: $showCalibration) {
                CalibrationView()
                    .environmentObject(faceTracker)
            }
        }
    }
}

// MARK: - Status Badges

struct ConnectionStatusBadge: View {
    let state: LiveLinkConnectionState
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(state.displayName)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    var statusColor: Color {
        switch state {
        case .disconnected: return .red
        case .discovering: return .yellow
        case .connecting: return .orange
        case .connected: return .blue
        case .streaming: return .green
        case .error: return .red
        }
    }
}

struct TrackingStatusBadge: View {
    let isTracking: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isTracking ? "face.smiling.fill" : "face.dashed")
                .foregroundColor(isTracking ? .green : .gray)
            Text(isTracking ? "Tracking" : "No Face")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

// MARK: - Blend Shape Visualization

struct BlendShapeVisualization: View {
    let blendShapes: [String: Float]
    
    private var topShapes: [(String, Float)] {
        blendShapes.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(topShapes, id: \.0) { name, value in
                HStack {
                    Text(name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 140, alignment: .trailing)
                    
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: geometry.size.width * CGFloat(value))
                    }
                    .frame(height: 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
                    
                    Text(String(format: "%.2f", value))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 40)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - AR Camera Preview (placeholder)

struct ARCameraPreview: UIViewRepresentable {
    var faceTracker: FaceTracker
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
