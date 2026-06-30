import SwiftUI

// MARK: - Models

private struct EduPath: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    let modules: [EduModule]
    let certTitle: String?
    let certHours: Int?
}

private struct EduModule: Identifiable {
    let id: String
    let title: String
    let lessons: Int
    let emoji: String
    var completed: Int = 0
    var locked: Bool = false

    var progress: Double { lessons > 0 ? Double(completed) / Double(lessons) : 0 }
    var isDone: Bool { completed >= lessons }
}

// MARK: - Static Content

private let paths: [EduPath] = [

    EduPath(
        id: "academic",
        title: "Academic Path",
        subtitle: "Common Core → College Prep",
        description: "Math, English, Science, History, and Geography aligned to K-12 standards and beyond. Each level unlocks through Brain Brawl performance.",
        icon: "graduationcap.fill",
        color: Color(red: 0.1, green: 0.7, blue: 1.0),
        modules: [
            EduModule(id: "k5_math",    title: "K-5 Math Foundations",        lessons: 12, emoji: "➕", completed: 0),
            EduModule(id: "k5_ela",     title: "K-5 Reading & Writing",       lessons: 10, emoji: "📖", completed: 0),
            EduModule(id: "68_math",    title: "6-8 Pre-Algebra & Algebra",   lessons: 14, emoji: "🔢", completed: 0, locked: false),
            EduModule(id: "68_sci",     title: "6-8 Earth & Life Science",    lessons: 12, emoji: "🧬", completed: 0, locked: false),
            EduModule(id: "68_hist",    title: "6-8 US & World History",      lessons: 10, emoji: "🌍", completed: 0, locked: false),
            EduModule(id: "912_math",   title: "9-12 Algebra II & Pre-Calc",  lessons: 16, emoji: "📐", completed: 0, locked: true),
            EduModule(id: "912_bio",    title: "9-12 Biology & Chemistry",    lessons: 14, emoji: "⚗️", completed: 0, locked: true),
            EduModule(id: "912_eng",    title: "9-12 English Composition",    lessons: 12, emoji: "✍️", completed: 0, locked: true),
            EduModule(id: "col_prep",   title: "College Prep & SAT/ACT",      lessons: 10, emoji: "🎓", completed: 0, locked: true),
            EduModule(id: "col_essay",  title: "College Essay Workshop",      lessons: 6,  emoji: "📝", completed: 0, locked: true),
        ],
        certTitle: nil,
        certHours: nil
    ),

    EduPath(
        id: "stem",
        title: "STEM Lab",
        subtitle: "Applied Science, Math & Coding",
        description: "Physics that explains vertical jumps, biomechanics backed by data, and intro to coding — all tied directly to athletic performance.",
        icon: "flask.fill",
        color: Color(red: 0, green: 0.9, blue: 0.85),
        modules: [
            EduModule(id: "stem_phys",  title: "Applied Physics — Force & Motion",       lessons: 10, emoji: "⚡️", completed: 0),
            EduModule(id: "stem_bio",   title: "Sports Biology — Muscles & Energy",       lessons: 10, emoji: "💪", completed: 0),
            EduModule(id: "stem_math",  title: "Data & Statistics for Athletes",          lessons: 8,  emoji: "📊", completed: 0),
            EduModule(id: "stem_code",  title: "Intro to Coding — Python Basics",         lessons: 12, emoji: "💻", completed: 0, locked: false),
            EduModule(id: "stem_chem",  title: "Nutrition Chemistry — Fuel & Recovery",   lessons: 8,  emoji: "🧪", completed: 0, locked: false),
            EduModule(id: "stem_eng",   title: "Wearable Tech & Sensor Engineering",      lessons: 8,  emoji: "📡", completed: 0, locked: true),
            EduModule(id: "stem_ai",    title: "AI & Machine Learning in Sport",          lessons: 10, emoji: "🤖", completed: 0, locked: true),
        ],
        certTitle: nil,
        certHours: nil
    ),

    EduPath(
        id: "kinesiology",
        title: "Applied Kinesiology",
        subtitle: "Certificate Program · 3.0 CEU Credits",
        description: "A structured 8-module certificate program grounding the science of human movement in credentialed learning. Completion earns a verifiable digital certificate.",
        icon: "figure.strengthtraining.traditional",
        color: Color(red: 0.95, green: 0.49, blue: 0.15),
        modules: [
            EduModule(id: "kin_anat",   title: "Module 1 — Human Anatomy",               lessons: 8,  emoji: "🦴", completed: 0),
            EduModule(id: "kin_bio",    title: "Module 2 — Biomechanics",                 lessons: 10, emoji: "📐", completed: 0),
            EduModule(id: "kin_physio", title: "Module 3 — Exercise Physiology",          lessons: 10, emoji: "❤️", completed: 0, locked: false),
            EduModule(id: "kin_motor",  title: "Module 4 — Motor Learning",               lessons: 8,  emoji: "🧠", completed: 0, locked: false),
            EduModule(id: "kin_nutr",   title: "Module 5 — Nutrition Science",            lessons: 8,  emoji: "🥦", completed: 0, locked: true),
            EduModule(id: "kin_injp",   title: "Module 6 — Injury Prevention",            lessons: 10, emoji: "🩹", completed: 0, locked: true),
            EduModule(id: "kin_prog",   title: "Module 7 — Program Design",               lessons: 10, emoji: "📋", completed: 0, locked: true),
            EduModule(id: "kin_asses",  title: "Module 8 — Assessment & Testing",         lessons: 8,  emoji: "📏", completed: 0, locked: true),
        ],
        certTitle: "Certificate in Applied Kinesiology",
        certHours: 3
    ),

    EduPath(
        id: "brain_brawl",
        title: "Brain Brawl Arena",
        subtitle: "Cognitive Combat · Reaction & Strategy",
        description: "Train your mind with sports knowledge, logic puzzles, and rapid-fire decision challenges. Win Brain Brawl matches to advance through cognitive levels and earn education shards.",
        icon: "brain.head.profile.fill",
        color: Color(red: 0.8, green: 0.2, blue: 0.9),
        modules: [
            EduModule(id: "bb_react",   title: "Reaction Speed Training",       lessons: 6,  emoji: "⚡️", completed: 0),
            EduModule(id: "bb_pattern", title: "Pattern Recognition",            lessons: 8,  emoji: "🔷", completed: 0),
            EduModule(id: "bb_sports",  title: "Sports Rules & IQ",              lessons: 10, emoji: "🏆", completed: 0, locked: false),
            EduModule(id: "bb_logic",   title: "Logic & Decision Under Pressure",lessons: 8,  emoji: "🧩", completed: 0, locked: true),
            EduModule(id: "bb_mental",  title: "Mental Performance Foundations", lessons: 8,  emoji: "🧠", completed: 0, locked: true),
        ],
        certTitle: nil,
        certHours: nil
    ),
]

// MARK: - Progress Storage (UserDefaults-backed)

private final class EduProgress: ObservableObject {
    @Published var completedLessons: [String: Int] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: "eduProgress"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            completedLessons = decoded
        }
    }

    func advance(moduleId: String, total: Int) {
        let current = completedLessons[moduleId] ?? 0
        if current < total {
            completedLessons[moduleId] = current + 1
            save()
        }
    }

    func completed(moduleId: String) -> Int {
        completedLessons[moduleId] ?? 0
    }

    private func save() {
        if let data = try? JSONEncoder().encode(completedLessons) {
            UserDefaults.standard.set(data, forKey: "eduProgress")
        }
    }
}

// MARK: - Main View

struct EducationHubView: View {
    let viewModel: LabViewModel

    @StateObject private var progress = EduProgress()
    @State private var expandedPath: String? = nil
    @State private var selectedModule: (EduPath, EduModule)? = nil
    @State private var showCert: EduPath? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                brainBrawlBridge
                ForEach(paths) { path in
                    pathCard(path)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .sheet(isPresented: Binding(
            get: { selectedModule != nil },
            set: { if !$0 { selectedModule = nil } }
        )) {
            if let (path, module) = selectedModule {
                LessonSheetView(path: path, module: module, progress: progress)
            }
        }
        .sheet(isPresented: Binding(
            get: { showCert != nil },
            set: { if !$0 { showCert = nil } }
        )) {
            if let path = showCert {
                CertificateView(path: path)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ACADEMY")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0, green: 0.9, blue: 0.85))
                .tracking(4)
            Text("Education Hub")
                .font(.system(size: 36, weight: .black))
                .italic()
                .foregroundStyle(.white)
            Text("Common Core → College Prep · STEM Lab · Applied Kinesiology Certificate")
                .font(.system(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Brain Brawl Bridge

    private var brainBrawlBridge: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.8, green: 0.2, blue: 0.9).opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.8, green: 0.2, blue: 0.9))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("BRAIN BRAWL — EARN PROGRESS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(red: 0.8, green: 0.2, blue: 0.9))
                    .tracking(1)
                Text("Win Brain Brawl categories to unlock modules and earn education shards.")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.8, green: 0.2, blue: 0.9).opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Path Card

    private func pathCard(_ path: EduPath) -> some View {
        let isExpanded = expandedPath == path.id
        let totalLessons = path.modules.map(\.lessons).reduce(0, +)
        let completedLessons = path.modules.map { progress.completed(moduleId: $0.id) }.reduce(0, +)
        let overallProgress = totalLessons > 0 ? Double(completedLessons) / Double(totalLessons) : 0
        let allDone = overallProgress >= 1.0

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.35)) {
                    expandedPath = isExpanded ? nil : path.id
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(path.color.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: path.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(path.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(path.subtitle.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(path.color.opacity(0.8))
                            .tracking(1)
                        Text(path.title)
                            .font(.system(.headline, weight: .black))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(overallProgress * 100))%")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(path.color)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.06))
                    Rectangle().fill(path.color)
                        .frame(width: geo.size.width * CGFloat(overallProgress))
                        .animation(.spring(response: 0.6), value: overallProgress)
                }
            }
            .frame(height: 3)

            // Expanded modules
            if isExpanded {
                VStack(spacing: 0) {
                    Text(path.description)
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    Divider().background(Color.white.opacity(0.06))

                    ForEach(path.modules) { module in
                        let comp = progress.completed(moduleId: module.id)
                        let mod = EduModule(id: module.id, title: module.title, lessons: module.lessons,
                                            emoji: module.emoji, completed: comp, locked: module.locked)
                        moduleRow(mod, path: path)
                        if module.id != path.modules.last?.id {
                            Divider().background(Color.white.opacity(0.04)).padding(.horizontal, 16)
                        }
                    }

                    // Certificate CTA
                    if let certTitle = path.certTitle {
                        Divider().background(Color.white.opacity(0.06))
                        Button {
                            if allDone { showCert = path }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: allDone ? "rosette" : "lock.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(allDone ? .yellow : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(certTitle)
                                        .font(.system(.subheadline, weight: .bold))
                                        .foregroundStyle(allDone ? .white : .secondary)
                                    if let hrs = path.certHours {
                                        Text("\(hrs).0 CEU Credits · Digital Certificate")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(allDone ? path.color : .secondary)
                                    }
                                }
                                Spacer()
                                if allDone {
                                    Text("CLAIM")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(.yellow)
                                        .clipShape(Capsule())
                                } else {
                                    Text("COMPLETE ALL")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(path.color.opacity(isExpanded ? 0.2 : 0.1), lineWidth: 1))
        )
        .clipShape(.rect(cornerRadius: 20))
    }

    private func moduleRow(_ module: EduModule, path: EduPath) -> some View {
        let comp = progress.completed(moduleId: module.id)
        let isDone = comp >= module.lessons

        return Button {
            guard !module.locked else { return }
            selectedModule = (path, module)
        } label: {
            HStack(spacing: 12) {
                Text(module.emoji)
                    .font(.system(size: 20))
                    .frame(width: 32)
                    .opacity(module.locked ? 0.4 : 1.0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(module.title)
                        .font(.system(.subheadline, weight: module.locked ? .regular : .semibold))
                        .foregroundStyle(module.locked ? .secondary : .white)
                    HStack(spacing: 6) {
                        Text("\(comp)/\(module.lessons) lessons")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if !module.locked && comp > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.08))
                                    Capsule().fill(path.color)
                                        .frame(width: geo.size.width * CGFloat(module.progress))
                                }
                            }
                            .frame(width: 60, height: 4)
                        }
                    }
                }

                Spacer()

                if module.locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(module.locked)
    }
}

// MARK: - Lesson Sheet

private struct LessonSheetView: View {
    let path: EduPath
    let module: EduModule
    @ObservedObject var progress: EduProgress
    @Environment(\.dismiss) private var dismiss

    @State private var currentLesson = 0
    @State private var showQuestion = false
    @State private var selectedAnswer: Int? = nil
    @State private var isCorrect: Bool? = nil

    private let sampleQuestions: [String] = [
        "What is the primary energy system used for a vertical jump?",
        "Name the muscle that connects the calf to the heel bone.",
        "What does CNS stand for in training science?",
        "Define 'ground reaction force' in one sentence.",
        "What phase of periodization maximizes power output?",
    ]

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(module.emoji + " " + module.title)
                                .font(.system(.headline, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Lesson \(min(currentLesson + 1, module.lessons)) of \(module.lessons)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Progress
                    let comp = progress.completed(moduleId: module.id)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3).fill(path.color)
                                .frame(width: geo.size.width * CGFloat(comp) / CGFloat(module.lessons))
                        }
                    }
                    .frame(height: 5)
                    .padding(.horizontal, 24)

                    // Lesson content placeholder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LESSON \(min(comp + 1, module.lessons))")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(path.color)
                            .tracking(2)

                        Text(lessonTitle(for: comp))
                            .font(.system(.title3, weight: .black))
                            .foregroundStyle(.white)

                        Text(lessonBody(for: comp, module: module))
                            .font(.system(.subheadline))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 16).fill(path.color.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 16).stroke(path.color.opacity(0.12), lineWidth: 1)))
                    .padding(.horizontal, 24)

                    // Complete lesson button
                    if comp < module.lessons {
                        Button {
                            progress.advance(moduleId: module.id, total: module.lessons)
                        } label: {
                            Text("MARK LESSON COMPLETE")
                                .font(.system(.subheadline, weight: .black))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(path.color)
                                .clipShape(.rect(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Module complete!")
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        .padding(.bottom, 24)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func lessonTitle(for index: Int) -> String {
        let titles = [
            "Introduction & Overview", "Core Concepts", "Practical Application",
            "Movement Mechanics", "Energy Systems", "Neural Activation",
            "Recovery Science", "Performance Testing", "Program Design", "Integration"
        ]
        return titles[index % titles.count]
    }

    private func lessonBody(for index: Int, module: EduModule) -> String {
        "This lesson covers \(module.title.lowercased()) at an applied level, connecting the science to what actually happens during training and competition. Research your concepts, apply them in your next session, and track how your metrics respond. Every lesson ties directly to your PRQ and readiness scores inside Final Evolution Lab."
    }
}

// MARK: - Certificate View

private struct CertificateView: View {
    let path: EduPath
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [path.color.opacity(0.2), Theme.deepBlack, Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "rosette")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(path.color)
                    .shadow(color: path.color.opacity(0.5), radius: 20)

                VStack(spacing: 8) {
                    Text("CERTIFICATE OF COMPLETION")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(path.color.opacity(0.8))
                        .tracking(3)
                    Text(path.certTitle ?? "Certificate")
                        .font(.system(size: 26, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    if let hrs = path.certHours {
                        Text("\(hrs).0 Continuing Education Units")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Issued by Final Evolution Lab · \(formattedDate)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {} label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("SHARE")
                        }
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(path.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(path.color.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(path.color.opacity(0.3), lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    Button { dismiss() } label: {
                        Text("DONE")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(path.color)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: Date())
    }
}
