import SwiftUI
import Combine

/// Workout stream catalog displaying live and archived feeds with interactive timelines,
/// schedules, and a live telemetry leaderboard showing active concurrent users.
struct StreamingPortalView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Mock database of stream sessions
    @State private var streams: [WorkoutStream] = [
        WorkoutStream(
            title: "Venice Beach Flight Session",
            trainer: "Coach Bonds",
            duration: "28 min",
            difficulty: "Elite",
            isLive: true,
            concurrentUsers: 142,
            streamURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_bipbop_active/bipbop_active.m3u8",
            imageName: "figure.run.square.stack"
        ),
        WorkoutStream(
            title: "Westside Power & Calisthenics",
            trainer: "Coach Marcus",
            duration: "35 min",
            difficulty: "Flight",
            isLive: false,
            concurrentUsers: 84,
            streamURL: "https://playertest.longtailvideo.com/adaptive/bipbop/bipbop.m3u8",
            imageName: "figure.strengthtraining.functional"
        ),
        WorkoutStream(
            title: "Heli-Pad Vertical Dunk Elite",
            trainer: "Coach Bonds",
            duration: "45 min",
            difficulty: "Elite",
            isLive: false,
            concurrentUsers: 215,
            streamURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_bipbop_active/bipbop_active.m3u8",
            imageName: "figure.basketball"
        )
    ]
    
    // Future classes schedule
    let schedule = [
        ScheduleClass(title: "Fascial Core Tension Mastery", trainer: "Coach Bonds", timeString: "Today, 6:00 PM", minutesLeft: 84),
        ScheduleClass(title: "Ankle Stiffening Flight Test", trainer: "Coach Marcus", timeString: "Tomorrow, 9:00 AM", minutesLeft: 980)
    ]
    
    // Leaderboard concurrent users data
    @State private var leaderboard: [LeaderboardUser] = [
        LeaderboardUser(name: "Elijah B. (You)", score: 845, shards: 45, isMe: true),
        LeaderboardUser(name: "Alex M.", score: 910, shards: 60, isMe: false),
        LeaderboardUser(name: "Marcus V.", score: 795, shards: 35, isMe: false),
        LeaderboardUser(name: "Sarah T.", score: 880, shards: 50, isMe: false),
        LeaderboardUser(name: "Coach Bonds", score: 1050, shards: 120, isMe: false)
    ]
    
    // Timer to simulate live leaderboard score increments
    let leaderboardTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Live Stream Hero Row
                liveHeroSection
                
                // Workout Catalog
                catalogSection
                
                // Live Concurrent Leaderboard
                leaderboardSection
                
                // Upcoming Schedule
                scheduleSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .navigationTitle("Streaming Portal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.streamingStub)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onReceive(leaderboardTimer) { _ in
            simulateLeaderboardActivity()
        }
    }
    
    // MARK: - Subviews
    
    private var liveHeroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let liveStream = streams.first(where: { $0.isLive }) {
                Text("CURRENTLY BROADCASTING")
                    .font(.system(.caption2, design: .monospaced, weight: .black))
                    .foregroundStyle(Color.red)
                    .tracking(2)
                    .flashingEffect()
                
                NavigationLink(destination: HlsPlayerView(videoTitle: liveStream.title, streamURL: liveStream.streamURL)) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(liveStream.title.uppercased())
                                    .font(.system(.title3, design: .monospaced, weight: .black))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                
                                Text("Lead Trainer: \(liveStream.trainer)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.brandCyan)
                            }
                            Spacer()
                            
                            // Difficulty Badge
                            Text(liveStream.difficulty.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Theme.elitePurple))
                        }
                        
                        HStack {
                            Label("\(liveStream.concurrentUsers) Active", systemImage: "person.3.fill")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Text("JOIN STREAM")
                                    .font(.system(.caption, design: .monospaced, weight: .heavy))
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                            }
                            .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.8), Theme.elitePurple.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                }
            }
        }
    }
    
    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VOD CATALOG")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)
            
            ForEach(streams) { stream in
                NavigationLink(destination: HlsPlayerView(videoTitle: stream.title, streamURL: stream.streamURL)) {
                    HStack(spacing: 14) {
                        // Icon block representation
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.brandCyan.opacity(0.08))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.cardBorder, lineWidth: 1)
                                )
                            Image(systemName: stream.imageName)
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.brandCyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(stream.title)
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                if stream.isLive {
                                    Text("LIVE")
                                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.red.cornerRadius(3))
                                }
                            }
                            
                            Text("\(stream.trainer) · \(stream.duration) · \(stream.difficulty)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 0.5))
                    )
                }
            }
        }
    }
    
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CONCURRENT COMPETITION")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Spacer()
                Text("LIVE LEADERBOARD")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.neonGreen)
            }
            
            VStack(spacing: 8) {
                ForEach(leaderboard.sorted(by: { $0.score > $1.score })) { user in
                    HStack(spacing: 12) {
                        Text(user.isMe ? "👉" : "👤")
                            .font(.caption)
                        
                        Text(user.name)
                            .font(.system(.subheadline, weight: user.isMe ? .bold : .medium))
                            .foregroundStyle(user.isMe ? Theme.brandCyan : .white)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("PRQ: \(user.score)")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.neonGreen)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Theme.brandCyan)
                                Text("\(user.shards)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(user.isMe ? Theme.brandCyan.opacity(0.06) : Color.white.opacity(0.02))
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
            )
        }
    }
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UPCOMING LIVE SESSIONS")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)
            
            ForEach(schedule, id: \.title) { classItem in
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(classItem.title)
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Trainer: \(classItem.trainer) · \(classItem.timeString)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Time countdown pill
                    Text(formatTimeLeft(minutes: classItem.minutesLeft))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.brandCyan.opacity(0.12)))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 0.5))
                )
            }
        }
    }
    
    // MARK: - Activity Simulation
    
    private func simulateLeaderboardActivity() {
        for idx in 0..<leaderboard.count {
            let increment = Int.random(in: 1...8)
            leaderboard[idx].score += increment
            
            // Randomly award shards occasionally
            if Int.random(in: 0...10) > 8 {
                leaderboard[idx].shards += 1
            }
        }
    }
    
    private func formatTimeLeft(minutes: Int) -> String {
        if minutes < 60 {
            return "IN \(minutes)M"
        } else {
            let hrs = minutes / 60
            let mins = minutes % 60
            return "IN \(hrs)H \(mins)M"
        }
    }
}

// MARK: - Models

struct WorkoutStream: Identifiable {
    let id = UUID()
    let title: String
    let trainer: String
    let duration: String
    let difficulty: String
    let isLive: Bool
    let concurrentUsers: Int
    let streamURL: String
    let imageName: String
}

struct ScheduleClass {
    let title: String
    let trainer: String
    let timeString: String
    let minutesLeft: Int
}

struct LeaderboardUser: Identifiable {
    let id = UUID()
    let name: String
    var score: Int
    var shards: Int
    let isMe: Bool
}
