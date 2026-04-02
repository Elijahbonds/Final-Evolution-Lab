// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: FEL Face Capture - Settings UI

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var connectionManager: LiveLinkConnectionManager
    @AppStorage("serverAddress") private var serverAddress: String = "192.168.1.100"
    @AppStorage("serverPort") private var serverPort: Int = 11111
    @AppStorage("subjectName") private var subjectName: String = "FELFaceCapture"
    @AppStorage("smoothingAlpha") private var smoothingAlpha: Double = 0.15
    @AppStorage("showDebugOverlay") private var showDebugOverlay: Bool = false
    @AppStorage("targetFPS") private var targetFPS: Int = 60
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Connection section
                Section(header: Text("Connection")) {
                    TextField("Server IP Address", text: $serverAddress)
                        .keyboardType(.decimalPad)
                    
                    Stepper("Port: \(serverPort)", value: $serverPort, in: 1024...65535)
                    
                    TextField("Subject Name", text: $subjectName)
                    
                    if !connectionManager.discoveredServers.isEmpty {
                        Section(header: Text("Discovered Servers")) {
                            ForEach(connectionManager.discoveredServers) { server in
                                Button(action: {
                                    serverAddress = server.host
                                    connectionManager.connectToServer(server)
                                }) {
                                    HStack {
                                        Image(systemName: "desktopcomputer")
                                        Text(server.name)
                                        Spacer()
                                        Text(server.host)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    Button("Scan for Servers") {
                        connectionManager.startDiscovery()
                    }
                }
                
                // Tracking section
                Section(header: Text("Tracking")) {
                    VStack(alignment: .leading) {
                        Text("Smoothing: \(String(format: "%.2f", smoothingAlpha))")
                        Slider(value: $smoothingAlpha, in: 0...0.5, step: 0.01)
                    }
                    
                    Picker("Target FPS", selection: $targetFPS) {
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Debug section
                Section(header: Text("Debug")) {
                    Toggle("Show Debug Overlay", isOn: $showDebugOverlay)
                    
                    HStack {
                        Text("Packets Sent")
                        Spacer()
                        Text("\(connectionManager.packetsSent)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Connection State")
                        Spacer()
                        Text(connectionManager.connectionState.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    if !connectionManager.errorMessage.isEmpty {
                        HStack {
                            Text("Error")
                            Spacer()
                            Text(connectionManager.errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                // About section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("ARKit Face Tracking")
                        Spacer()
                        Text(FaceTracker.isFaceTrackingSupported ? "Supported" : "Not Supported")
                            .foregroundColor(FaceTracker.isFaceTrackingSupported ? .green : .red)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Apply settings
                        connectionManager.serverAddress = serverAddress
                        connectionManager.serverPort = UInt16(serverPort)
                        connectionManager.subjectName = subjectName
                        dismiss()
                    }
                }
            }
        }
    }
}
