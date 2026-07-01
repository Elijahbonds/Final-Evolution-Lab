import SwiftUI

struct BrainBrawlPostGameView: View {
    let correctCount: Int
    let totalCount: Int
    let shardsEarned: Int
    let readinessBonus: Double
    let oldOverallXP: Int
    let newOverallXP: Int
    let categoryAnswers: [BrainBrawlCategory: (correct: Int, total: Int)]
    let progression: BrainBrawlProgression
    
    @Environment(\.dismiss) private var dismiss
    @State private var animateProgress = false
    @State private var showLevelUpCelebration = false
    
    private var leveledUp: Bool {
        let oldLevel = BrainBrawlProgression.calculateLevel(forXP: oldOverallXP)
        let newLevel = BrainBrawlProgression.calculateLevel(forXP: newOverallXP)
        return newLevel > oldLevel
    }
    
    var body: some View {
        ZStack {
            Theme.deepBlack
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 6) {
                        Text("BRAIN BRAWL")
                            .font(.system(.caption2, design: .monospaced).weight(.black))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(4)
                        
                        Text("SESSION SUMMARY")
                            .font(.system(.title2, design: .monospaced).weight(.black))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 24)
                    
                    // Level Up Celebration Overlay
                    if showLevelUpCelebration {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.neonGreen)
                            
                            Text("LEVEL UP!")
                                .font(.system(.title, design: .monospaced).weight(.black))
                                .foregroundStyle(Theme.neonGreen)
                                .shadow(color: Theme.neonGreen.opacity(0.6), radius: 10)
                            
                            Text("You reached Level \(BrainBrawlProgression.calculateLevel(forXP: newOverallXP))!")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.neonGreen.opacity(0.4), lineWidth: 2)
                                .background(Theme.cardBackground)
                        )
                        .transition(.scale.combined(with: .opacity))
                        .padding(.horizontal)
                    }
                    
                    // Score Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ACCURACY")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                                Text("\(correctCount) / \(totalCount) Correct")
                                    .font(.system(.title3, design: .monospaced).weight(.bold))
                                    .foregroundStyle(Theme.brandCyan)
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", Double(correctCount) / Double(max(1, totalCount)) * 100))
                                .font(.system(size: 36, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SHARDS EARNED")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                                HStack(spacing: 4) {
                                    Image(systemName: "hexagon.fill")
                                        .foregroundStyle(.yellow)
                                    Text("+\(shardsEarned)")
                                        .font(.system(.headline, design: .monospaced).weight(.bold))
                                        .foregroundStyle(.yellow)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("READINESS BONUS")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(String(format: "+%.1f%%", readinessBonus))
                                    .font(.system(.headline, design: .monospaced).weight(.bold))
                                    .foregroundStyle(Theme.neonGreen)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // Overall XP Progression
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("OVERALL LEVEL \(BrainBrawlProgression.calculateLevel(forXP: newOverallXP))")
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(newOverallXP % 1000) / 1000 XP")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.brandBlue, Theme.brandCyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(animateProgress ? BrainBrawlProgression.xpProgress(forXP: newOverallXP) : BrainBrawlProgression.xpProgress(forXP: oldOverallXP)), height: 12)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // Category Analytics
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CROWN WHEEL ANALYTICS")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(2)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(BrainBrawlCategory.allCases, id: \.self) { category in
                                let stats = categoryAnswers[category] ?? (correct: 0, total: 0)
                                let catXP = progression.categoryXP[category.rawValue] ?? 0
                                let catLevel = progression.levelForCategory(category)
                                let catProgress = progression.xpProgressForCategory(category)
                                let catRatio = progression.correctRatioForCategory(category)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: category.iconName)
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.brandCyan)
                                        Spacer()
                                        Text("LVL \(catLevel)")
                                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                    
                                    Text(category.displayName)
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .lineLimit(1)
                                    
                                    // Progress Bar
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(height: 6)
                                        
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Theme.brandCyan)
                                            .frame(width: 140 * CGFloat(animateProgress ? catProgress : 0.0), height: 6)
                                    }
                                    
                                    HStack {
                                        Text(String(format: "%.0f%% Accuracy", catRatio * 100))
                                            .font(.system(size: 10, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.6))
                                        Spacer()
                                        HStack(spacing: 4) {
                                            if progression.crownsForCategory(category) > 0 {
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.yellow)
                                                Text("\(progression.crownsForCategory(category))")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(.yellow)
                                            }
                                            if stats.total > 0 {
                                                Text("+\(stats.correct * 50) XP")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(Theme.neonGreen)
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Theme.surfaceElevated)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.cardBorder, lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Done Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("DONE")
                            .font(.system(.subheadline, design: .monospaced).weight(.black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.brandCyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Theme.brandCyan.opacity(0.3), radius: 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateProgress = true
            }
            if leveledUp {
                withAnimation(.spring().delay(0.5)) {
                    showLevelUpCelebration = true
                }
            }
        }
    }
}
