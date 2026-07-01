import SwiftUI

struct AcademicLesson: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let durationMin: Int
    let contentBlocks: [ContentBlock]
    let quiz: [QuizQuestion]
    
    struct ContentBlock: Hashable {
        let type: String
        let heading: String
        let body: String
        let items: [String]?
    }
    
    struct QuizQuestion: Hashable {
        let q: String
        let options: [String]
        let correct: Int
    }
}

struct AcademicTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    let lessons: [AcademicLesson]
}

struct AcademicLessonRunnerView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTrack: AcademicTrack? = nil
    @State private var activeLesson: AcademicLesson? = nil
    @State private var quizAnswers: [Int] = []
    @State private var showQuizResult = false
    @State private var quizResultCorrect = 0
    @State private var quizResultXP = 0
    @State private var quizResultPassed = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var localProgress = AcademicProgress()
    
    // Seed content matching backend/routers/education_tracks.py
    private let tracks: [AcademicTrack] = [
        AcademicTrack(
            id: "common_core",
            title: "Common Core Pathway",
            subtitle: "Athlete Academic Readiness — ELA · Math · Science · Civics",
            description: "College-prep grounding aligned to NCAA eligibility. Scholarship-grade reading, math reasoning, lab science, and U.S. civics for the next-gen athlete.",
            icon: "book.closed.fill",
            color: Color(red: 0.06, green: 0.72, blue: 0.51),
            lessons: [
                AcademicLesson(
                    id: "cc_ela_1",
                    title: "Argumentative Reading & Rhetoric",
                    summary: "Decode authorial intent, evidence, and counter-claim construction in non-fiction sport journalism.",
                    durationMin: 22,
                    contentBlocks: [
                        AcademicLesson.ContentBlock(type: "text", heading: "Why this matters", body: "Scholarship committees and NCAA pathways reward claims backed by evidence—not vibes. Sport journalism is a practical training ground for spotting weak reasoning.", items: nil),
                        AcademicLesson.ContentBlock(type: "bullets", heading: "Work through", body: "", items: ["Underline the author’s central claim.", "Circle evidence vs. opinion.", "Note where a counter-claim would strengthen the argument."])
                    ],
                    quiz: [
                        AcademicLesson.QuizQuestion(q: "A claim supported only by a single anecdote is best described as:", options: ["Empirical", "Anecdotal", "Statistical", "Axiomatic"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "An author's purpose to refute a prior idea is most often signaled by:", options: ["However / Conversely", "In addition", "For example", "First"], correct: 0),
                        AcademicLesson.QuizQuestion(q: "Which is strongest evidence in a scholarship essay?", options: ["Personal opinion", "Cited longitudinal study", "Single quote", "Hashtag trend"], correct: 1)
                    ]
                ),
                AcademicLesson(
                    id: "cc_math_1",
                    title: "Algebraic Reasoning for Performance",
                    summary: "Linear models, rates of change, and slope as 'velocity of progress'. Modeling jump-height growth over weeks.",
                    durationMin: 25,
                    contentBlocks: [
                        AcademicLesson.ContentBlock(type: "text", heading: "Why this matters", body: "Algebra isn't just abstract symbols; it's the language of growth. If you can model your progress, you can predict your peak performance.", items: nil),
                        AcademicLesson.ContentBlock(type: "bullets", heading: "Key concepts", body: "", items: ["Linear growth: y = mx + b", "Slope (m) is your rate of improvement.", "Intercept (b) is your starting baseline."])
                    ],
                    quiz: [
                        AcademicLesson.QuizQuestion(q: "If your vertical jump grows 0.4 in/week from 24 in, what is it at week 8?", options: ["27.0 in", "27.2 in", "26.8 in", "28.0 in"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Slope in y = mx + b represents:", options: ["Y-intercept", "Rate of change", "Constant", "Domain"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Solve: 3(x − 4) = 18", options: ["x = 6", "x = 10", "x = 4", "x = 14"], correct: 1)
                    ]
                ),
                AcademicLesson(
                    id: "cc_sci_1",
                    title: "Scientific Method in Training",
                    summary: "Hypothesis, control group, p-value intuition, and why anecdote ≠ data.",
                    durationMin: 18,
                    contentBlocks: [
                        AcademicLesson.ContentBlock(type: "text", heading: "Why this matters", body: "To optimize your training, you must think like a scientist. Isolate your variables, track your data, and don't rely on hype.", items: nil),
                        AcademicLesson.ContentBlock(type: "bullets", heading: "Key steps", body: "", items: ["Formulate a testable hypothesis.", "Establish a control group to isolate variables.", "Analyze data over a significant sample size."])
                    ],
                    quiz: [
                        AcademicLesson.QuizQuestion(q: "Which is a testable hypothesis?", options: ["Athletes are better", "Plyometrics increase vertical by ≥2 in over 6 weeks", "Sports are fun", "Basketball wins"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "A control group is used to:", options: ["Win the study", "Isolate the variable", "Pad the numbers", "Replace data"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Sample size matters because:", options: ["Larger is more impressive", "Reduces sampling error", "Gets more sponsors", "Looks scientific"], correct: 1)
                    ]
                )
            ]
        ),
        AcademicTrack(
            id: "stem",
            title: "STEM in Sports Science",
            subtitle: "Physics · Analytics · Nutrition · Sports Tech",
            description: "Quantitative principles of human performance — from kinematics to data pipelines and applied nutrition.",
            icon: "atom",
            color: .cyan,
            lessons: [
                AcademicLesson(
                    id: "stem_phys_1",
                    title: "Kinematics of the Vertical Jump",
                    summary: "Impulse-momentum, hang time, and why takeoff velocity > arm swing.",
                    durationMin: 20,
                    contentBlocks: [
                        AcademicLesson.ContentBlock(type: "text", heading: "Why this matters", body: "Your vertical jump is a direct result of physics. By understanding force, time, and impulse, you can maximize your launch velocity.", items: nil),
                        AcademicLesson.ContentBlock(type: "bullets", heading: "Kinematic pillars", body: "", items: ["Impulse = Force × Time", "Takeoff velocity determines peak height.", "Gravity acts as a constant deceleration (9.8 m/s²)."])
                    ],
                    quiz: [
                        AcademicLesson.QuizQuestion(q: "Hang time of a 36-in vertical (≈0.91m): closest to", options: ["0.4 s", "0.86 s", "1.4 s", "2.0 s"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Impulse equals:", options: ["F·d", "F·t", "m·a", "P·V"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Greater takeoff velocity primarily comes from:", options: ["Arm swing", "Ground reaction force × time", "Shouting", "Pre-jump hop"], correct: 1)
                    ]
                ),
                AcademicLesson(
                    id: "stem_an_1",
                    title: "Sports Analytics 101",
                    summary: "Possessions, true shooting %, and signal vs. noise in small samples.",
                    durationMin: 22,
                    contentBlocks: [
                        AcademicLesson.ContentBlock(type: "text", heading: "Why this matters", body: "Modern sports are won in the spreadsheet as much as on the court. Analytics help normalize pace and isolate true efficiency.", items: nil),
                        AcademicLesson.ContentBlock(type: "bullets", heading: "Analytical metrics", body: "", items: ["True Shooting % accounts for 3PT and FT efficiency.", "Per-100 possessions normalizes team pace.", "Small sample sizes lead to high variance and noise."])
                    ],
                    quiz: [
                        AcademicLesson.QuizQuestion(q: "True Shooting % accounts for:", options: ["FG only", "FG + 3PT + FT efficiency", "Steals", "Assists"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Per-100 possessions normalizes:", options: ["Player size", "Pace", "Salary", "Team logos"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Small sample sizes are prone to:", options: ["Truth", "Variance/noise", "Bias-free signal", "Always wrong"], correct: 1)
                    ]
                ),
                AcademicLesson(
                    id: "stem_nut_1",
                    title: "Sports Nutrition — Macros & Timing",
                    summary: "Protein synthesis windows, carb timing for glycogen, and hydration math.",
                    durationMin: 18,
                    contentBlocks: [
                        AcademicLesson.ContentBlock(type: "text", heading: "Why this matters", body: "Food is fuel. Proper macronutrient distribution and timing can accelerate recovery and sustain peak power output.", items: nil),
                        AcademicLesson.ContentBlock(type: "bullets", heading: "Nutrition guidelines", body: "", items: ["Protein: 1.6–2.2g per kg of body weight for hypertrophy.", "Carbohydrates: Replenish muscle glycogen post-training.", "Dehydration: Even 2% body weight loss degrades performance."])
                    ],
                    quiz: [
                        AcademicLesson.QuizQuestion(q: "Daily protein for hypertrophy (per kg BW):", options: ["0.4–0.6 g", "1.6–2.2 g", "3.5–4.5 g", "6+ g"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Post-training carbs replenish:", options: ["Hemoglobin", "Glycogen", "Calcium", "Cortisol"], correct: 1),
                        AcademicLesson.QuizQuestion(q: "Mild dehydration (~2% BW) reduces performance by ≈", options: ["0%", "10–20%", "50%", "Improves it"], correct: 1)
                    ]
                )
            ]
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                
                if let track = selectedTrack {
                    if let lesson = activeLesson {
                        lessonView(track: track, lesson: lesson)
                    } else {
                        trackDetailView(track: track)
                    }
                } else {
                    trackListView
                }
                
                if showToast {
                    toastOverlay
                }
            }
            .navigationTitle(selectedTrack == nil ? "Academy" : selectedTrack!.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedTrack != nil {
                        Button {
                            if activeLesson != nil {
                                activeLesson = nil
                            } else {
                                selectedTrack = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundStyle(Theme.brandCyan)
                        }
                    } else {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundStyle(Theme.brandCyan)
                    }
                }
            }
            .onAppear {
                if let progress = viewModel.profile.academicProgress {
                    self.localProgress = progress
                } else {
                    self.localProgress = AcademicProgress()
                }
            }
        }
    }
    
    private var trackListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACADEMIC PATHWAYS")
                        .font(.system(.caption2, design: .monospaced, weight: .black))
                        .foregroundStyle(Theme.brandBlue)
                        .tracking(3)
                    
                    Text("NCAA Eligibility & Sports Science Mastery")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("Earn XP and build your academic profile by completing Common Core and STEM tracks designed for elite student-athletes.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                VStack(spacing: 16) {
                    ForEach(tracks) { track in
                        Button {
                            selectedTrack = track
                        } label: {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(track.color.opacity(0.15))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: track.icon)
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundStyle(track.color)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.title.uppercased())
                                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                                            .foregroundStyle(.white)
                                        
                                        Text(track.subtitle)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                
                                Text(track.description)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // Progress Bar
                                let completed = localProgress.trackProgress[track.id]?.completedLessons.count ?? 0
                                let total = track.lessons.count
                                let percent = total > 0 ? Double(completed) / Double(total) : 0.0
                                
                                VStack(spacing: 6) {
                                    HStack {
                                        Text("PROGRESS")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(track.color.opacity(0.8))
                                        Spacer()
                                        Text("\(completed)/\(total) LESSONS")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(height: 6)
                                            Capsule()
                                                .fill(track.color)
                                                .frame(width: geo.size.width * CGFloat(percent), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                                .padding(.top, 4)
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Theme.cardBorder, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }
    
    private func trackDetailView(track: AcademicTrack) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Track Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: track.icon)
                            .font(.title)
                            .foregroundStyle(track.color)
                        Text(track.title)
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                    }
                    
                    Text(track.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(track.color.opacity(0.25), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                .padding(.top, 16)
                
                Text("LESSONS")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(track.color.opacity(0.8))
                    .tracking(2)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                VStack(spacing: 12) {
                    ForEach(track.lessons) { lesson in
                        let isCompleted = localProgress.trackProgress[track.id]?.completedLessons.contains(lesson.id) ?? false
                        
                        Button {
                            quizAnswers = Array(repeating: -1, count: lesson.quiz.count)
                            activeLesson = lesson
                            showQuizResult = false
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(isCompleted ? track.color.opacity(0.15) : Color.white.opacity(0.05))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(isCompleted ? track.color : .white.opacity(0.6))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lesson.title)
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                    
                                    Text(lesson.summary)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text("\(lesson.durationMin)m")
                                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                                }
                                .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(isCompleted ? track.color.opacity(0.15) : Theme.cardBorder, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }
    
    private func lessonView(track: AcademicTrack, lesson: AcademicLesson) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Lesson Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(track.title.uppercased())
                            .font(.system(.caption2, design: .monospaced, weight: .black))
                            .foregroundStyle(track.color)
                            .tracking(2)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("\(lesson.durationMin) min study")
                        }
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Text(lesson.title)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                    
                    Text(lesson.summary)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Content Blocks (Briefing Cards)
                VStack(spacing: 16) {
                    ForEach(lesson.contentBlocks, id: \.self) { block in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(track.color)
                                    .frame(width: 4, height: 16)
                                Text(block.heading.uppercased())
                                    .font(.system(.caption, design: .monospaced, weight: .black))
                                    .foregroundStyle(track.color)
                                    .tracking(1.5)
                            }
                            
                            if !block.body.isEmpty {
                                Text(block.body)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            if let items = block.items {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(items, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("•")
                                                .foregroundStyle(track.color)
                                                .font(.system(size: 18, weight: .bold))
                                            Text(item)
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.75))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(.leading, 4)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Theme.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal)
                
                // Interactive Quiz Section
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(track.color)
                        Text("KNOWLEDGE CHECK")
                            .font(.system(.caption, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                            .tracking(2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    VStack(spacing: 24) {
                        ForEach(0..<lesson.quiz.count, id: \.self) { qIndex in
                            let question = lesson.quiz[qIndex]
                            VStack(alignment: .leading, spacing: 14) {
                                Text("\(qIndex + 1). \(question.q)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                VStack(spacing: 10) {
                                    ForEach(0..<question.options.count, id: \.self) { optIndex in
                                        let option = question.options[optIndex]
                                        let isSelected = quizAnswers[qIndex] == optIndex
                                        
                                        Button {
                                            if !showQuizResult {
                                                quizAnswers[qIndex] = optIndex
                                            }
                                        } label: {
                                            HStack {
                                                Text(option)
                                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                                    .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                                                Spacer()
                                                
                                                if showQuizResult {
                                                    if optIndex == question.correct {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundStyle(isSelected ? .black : .green)
                                                    } else if isSelected {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundStyle(.red)
                                                    }
                                                } else {
                                                    Circle()
                                                        .stroke(isSelected ? track.color : Color.white.opacity(0.2), lineWidth: 2)
                                                        .frame(width: 18, height: 18)
                                                        .overlay(
                                                            Circle()
                                                                .fill(isSelected ? track.color : Color.clear)
                                                                .padding(4)
                                                        )
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(isSelected ? track.color : Color.white.opacity(0.03))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(isSelected ? track.color : Color.white.opacity(0.08), lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(showQuizResult)
                                    }
                                }
                            }
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.cardBackground))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Submit Button / Results Card
                    if showQuizResult {
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Image(systemName: quizResultPassed ? "trophy.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(quizResultPassed ? .yellow : .orange)
                                
                                Text(quizResultPassed ? "LESSON PASSED!" : "TRY AGAIN")
                                    .font(.system(.title3, design: .rounded, weight: .black))
                                    .foregroundStyle(.white)
                                
                                Text("You scored \(quizResultCorrect) out of \(lesson.quiz.count) correct.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                
                                if quizResultXP > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill")
                                            .foregroundStyle(.yellow)
                                        Text("+\(quizResultXP) XP AWARDED")
                                            .font(.system(.caption, design: .monospaced, weight: .bold))
                                            .foregroundStyle(.yellow)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(quizResultPassed ? track.color.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                            .padding(.horizontal)
                            
                            Button {
                                activeLesson = nil
                            } label: {
                                Text("CONTINUE PATHWAY")
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Capsule().fill(track.color))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                        .padding(.top, 12)
                    } else {
                        let allAnswered = !quizAnswers.contains(-1)
                        
                        Button {
                            submitQuiz(track: track, lesson: lesson)
                        } label: {
                            Text("SUBMIT ANSWERS")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(allAnswered ? .black : .white.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Capsule().fill(allAnswered ? track.color : Color.white.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!allAnswered)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private var toastOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text(toastMessage)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.95)).shadow(radius: 10))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 24)
        }
    }
    
    private func submitQuiz(track: AcademicTrack, lesson: AcademicLesson) {
        var correct = 0
        for i in 0..<lesson.quiz.count {
            if quizAnswers[i] == lesson.quiz[i].correct {
                correct += 1
            }
        }
        
        let score = Double(correct) / Double(lesson.quiz.count)
        let passed = score >= 0.75
        
        var xpGained = 0
        let isAlreadyCompleted = localProgress.trackProgress[track.id]?.completedLessons.contains(lesson.id) ?? false
        
        if passed && !isAlreadyCompleted {
            xpGained = 50
            // Update profile XP and academic progress
            var updatedProfile = viewModel.profile
            var progress = updatedProfile.academicProgress ?? AcademicProgress()
            progress.addResult(trackId: track.id, lessonId: lesson.id, correct: correct, total: lesson.quiz.count, xpGained: xpGained)
            updatedProfile.academicProgress = progress
            
            // Increment profile stats
            updatedProfile.metrics.neuralDrive = min(100, updatedProfile.metrics.neuralDrive + 2.0)
            
            // Save to UserDefaults
            SaveSystem.saveProfile(updatedProfile)
            viewModel.profile = updatedProfile
            self.localProgress = progress
            
            toastMessage = "ACADEMIC XP GAINED: +50 XP"
            withAnimation {
                showToast = true
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation {
                    showToast = false
                }
            }
        } else if passed {
            // Re-passing doesn't award XP, but we still update local progress
            var updatedProfile = viewModel.profile
            var progress = updatedProfile.academicProgress ?? AcademicProgress()
            progress.addResult(trackId: track.id, lessonId: lesson.id, correct: correct, total: lesson.quiz.count, xpGained: 0)
            updatedProfile.academicProgress = progress
            SaveSystem.saveProfile(updatedProfile)
            viewModel.profile = updatedProfile
            self.localProgress = progress
        }
        
        self.quizResultCorrect = correct
        self.quizResultXP = xpGained
        self.quizResultPassed = passed
        withAnimation {
            self.showQuizResult = true
        }
    }
}
