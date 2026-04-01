// Copyright (c) Final Evolution Lab.
// Streaming Arena View — displays the Pixel Streaming feed from UE5
// with overlay controls for mode selection and exercise demos.

import SwiftUI

struct StreamingArenaView: View {
    @StateObject private var streaming = PixelStreamingService.shared
    @State private var showModeSelector = false
    @State private var showExercises = false
    @State private var selectedModeKey: String?
    
    var body: some View {
        ZStack {
            // Background
            Theme.deepBlack.ignoresSafeArea()
            
            if streaming.connectionState == .streaming {
                // Pixel Streaming video view would be here
                // In production, this uses WebRTC video rendering
                streamingVideoPlaceholder
            } else {
                connectionView
            }
            
            // HUD overlay
            VStack {
                hudTopBar
                Spacer()
                hudBottomBar
            }
        }
        .sheet(isPresented: $showModeSelector) {
            modeSelectorSheet
        }
        .sheet(isPresented: $showExercises) {
            exerciseDemoSheet
        }
        .onAppear {
            streaming.connect()
        }
    }
    
    // MARK: - Subviews
    
    private var connectionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundColor(Theme.brandCyan)
            
            Text("Final Evolution Arena")
                .font(.title.bold())
            
            Text(connectionStatusText)
                .foregroundColor(.secondary)
            
            if streaming.connectionState == .error {
                Button("Retry Connection") {
                    streaming.connect()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandCyan)
            }
            
            if streaming.streamerConnected {
                Button("Choose Game Mode") {
                    showModeSelector = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandBlue)
                .font(.headline)
            }
        }
        .padding()
    }
    
    private var streamingVideoPlaceholder: some View {
        Rectangle()
            .fill(Color.black)
            .overlay(
                VStack {
                    ProgressView()
                        .scaleEffect(2)
                    Text("Streaming: \(streaming.activeMode ?? "loading")")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            )
    }
    
    private var hudTopBar: some View {
        HStack {
            // Connection indicators
            HStack(spacing: 8) {
                Circle()
                    .fill(streaming.streamerConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(streaming.streamerConnected ? "UE5" : "Offline")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            Spacer()
            
            if let mode = streaming.activeMode {
                Text(mode.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.brandCyan.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var hudBottomBar: some View {
        HStack(spacing: 16) {
            Button(action: { showModeSelector = true }) {
                Label("Modes", systemImage: "gamecontroller")
                    .font(.caption.bold())
            }
            .buttonStyle(HudButtonStyle())
            
            Button(action: { showExercises = true }) {
                Label("Exercises", systemImage: "figure.run")
                    .font(.caption.bold())
            }
            .buttonStyle(HudButtonStyle())
            
            Spacer()
            
            if streaming.activeMode != nil {
                Button(action: { streaming.exitMode() }) {
                    Label("Exit", systemImage: "xmark.circle")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
                .buttonStyle(HudButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    private var modeSelectorSheet: some View {
        NavigationView {
            StreamingModeListView()
                .navigationTitle("Game Modes")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showModeSelector = false }
                    }
                }
        }
    }
    
    private var exerciseDemoSheet: some View {
        NavigationView {
            StreamingExerciseListView()
                .navigationTitle("3D Exercises")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showExercises = false }
                    }
                }
        }
    }
    
    private var connectionStatusText: String {
        switch streaming.connectionState {
        case .disconnected: return "Not connected to game server"
        case .connecting: return "Connecting to streaming server..."
        case .connected: return streaming.streamerConnected
            ? "Game server online — choose a mode"
            : "Connected — waiting for game server"
        case .streaming: return "Streaming active"
        case .error: return "Connection failed"
        }
    }
}

// MARK: - Mode List

struct StreamingModeListView: View {
    @StateObject private var streaming = PixelStreamingService.shared
    
    private let modes: [(key: String, name: String, icon: String)] = [
        ("basketball_h2h", "Street · 1v1", "\u{1F3C0}"),
        ("basketball_dunk", "Dunk Contest", "\u{1F93E}"),
        ("basketball_3v3", "Street · 3v3", "\u{1F3C0}"),
        ("karate_h2h", "Karate · 1v1", "\u{1F94B}"),
        ("karate_endless", "Karate · Endless", "\u{1F94B}"),
        ("baseball", "Baseball", "\u{26BE}"),
        ("football", "Football · Kick Return", "\u{1F3C8}"),
        ("soccer", "Soccer · Stadium", "\u{26BD}"),
        ("golf", "Golf · Links", "\u{26F3}"),
        ("tennis", "Tennis · Court", "\u{1F3BE}"),
        ("volleyball", "Volleyball · Sand", "\u{1F3D0}"),
        ("gymnastics", "Gymnastics · Floor", "\u{1F938}"),
        ("brain_brawl", "Brain Brawl", "\u{1F9E0}"),
        ("surfing", "Surf · Line", "\u{1F3C4}"),
        ("skateboarding", "Skate · Park", "\u{1F6F9}"),
        ("snowboarding", "Snow · Line", "\u{1F3C2}"),
    ]
    
    var body: some View {
        List(modes, id: \.key) { mode in
            Button(action: {
                streaming.launchMode(mode.key)
            }) {
                HStack {
                    Text(mode.icon)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text(mode.name)
                            .font(.headline)
                        Text(mode.key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if streaming.activeMode == mode.key {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .disabled(!streaming.streamerConnected)
        }
    }
}

// MARK: - Exercise List

struct StreamingExerciseListView: View {
    @StateObject private var streaming = PixelStreamingService.shared
    
    private let exercises: [(id: String, name: String, desc: String)] = [
        ("squat_form", "Perfect Form Squat", "Full-depth bodyweight squat"),
        ("box_jump", "Box Jump", "Explosive vertical jump"),
        ("dunk_approach", "Dunk Approach Pattern", "Sprint → gather → leap"),
        ("hip_90_90", "90/90 Hip Rotation", "Hip capsule mobility"),
        ("golf_swing_drill", "Golf Swing Plane", "Slow-motion swing focus"),
        ("karate_kata_basic", "Basic Kata Sequence", "Foundational kata"),
        ("serve_motion", "Tennis Serve Motion", "Full kinetic chain"),
        ("surf_popup", "Surf Pop-Up Drill", "Takeoff speed and balance"),
        ("balance_board", "Balance Board Training", "Proprioceptive training"),
        ("breathing_box", "Box Breathing", "4-4-4-4 recovery breathing"),
    ]
    
    var body: some View {
        List(exercises, id: \.id) { exercise in
            Button(action: {
                streaming.playExerciseDemo(exercise.id)
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(exercise.desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!streaming.streamerConnected)
        }
    }
}

// MARK: - HUD Button Style

struct HudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
