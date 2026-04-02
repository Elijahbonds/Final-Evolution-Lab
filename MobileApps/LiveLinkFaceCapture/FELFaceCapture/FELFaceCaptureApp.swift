// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: FEL Face Capture iOS App - Main Entry Point

import SwiftUI

@main
struct FELFaceCaptureApp: App {
    @StateObject private var faceTracker = FaceTracker()
    @StateObject private var connectionManager = LiveLinkConnectionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(faceTracker)
                .environmentObject(connectionManager)
        }
    }
}
