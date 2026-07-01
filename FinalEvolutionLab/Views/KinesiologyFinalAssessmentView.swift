import SwiftUI

enum ExamState {
    case loading
    case intro
    case active(KinesiologyAssessmentSession)
    case graded(KinesiologyAssessmentResult)
    case error(String)
}

struct KinesiologyFinalAssessmentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = AnatomyEducationService.shared
    
    @State private var state: ExamState = .intro
    @State private var selectedAnswers: [Int] = [] // -1 represents unanswered
    @State private var currentQuestionIndex: Int = 0
    @State private var timeRemainingString: String = "15:00"
    @State private var timer: Timer?
    @State private var expirationDate: Date?
    
    @State private var isSubmitting = false
    @State private var showSubmitConfirmation = false
    
    @State private var isClaiming = false
    @State private var claimedCertificate: CertificateClaimResult?
    
    // Sharing & Save states
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showShareAlert = false
    @State private var shareAlertMessage = ""
    @State private var isSharingToFeed = false
    
    var body: some View {
        ZStack {
            Theme.deepBlack
                .ignoresSafeArea()
            
            switch state {
            case .loading:
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Theme.brandCyan)
                    Text("ESTABLISHING SECURE PROCTOR CONNECTION...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
            case .intro:
                introView
                
            case .active(let session):
                activeExamView(session)
                
            case .graded(let result):
                gradedView(result)
                
            case .error(let message):
                errorView(message)
            }
        }
        .navigationTitle("Applied Kinesiology Final")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Intro View
    private var introView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(Theme.brandCyan)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("PROCTORED ASSESSMENT")
                    .font(.system(.caption2, design: .monospaced).weight(.black))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(3)
                
                Text("APPLIED KINESIOLOGY CERTIFICATION")
                    .font(.system(.title3, design: .monospaced).weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("This final exam evaluates your biomechanical knowledge, kinetic chain concepts, and interpretation of live gyroscopic data.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider().background(Color.white.opacity(0.12))
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "list.number")
                        .foregroundStyle(Theme.brandCyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Structure")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text("10 randomized questions with single option inputs.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.brandCyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Passing Criteria")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text("80% minimum score (8 out of 10 correct answers).")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(Theme.brandCyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text("15-minute active window. Session automatically submits.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(20)
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
            
            Button {
                Task {
                    await startExam()
                }
            } label: {
                Text("BEGIN FINAL ASSESSMENT")
                    .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Theme.brandCyan, Theme.brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Active Exam View
    private func activeExamView(_ session: KinesiologyAssessmentSession) -> some View {
        VStack(spacing: 16) {
            // Proctor status bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROCTOR STATUS: ACTIVE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                    Text("SESSION ID: \(session.id.prefix(8))...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text(timeRemainingString)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Progress tracker
            HStack {
                Text("Question \(currentQuestionIndex + 1) of \(session.questions.count)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(selectedAnswers.filter { $0 != -1 }.count) / \(session.questions.count) Answered")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.brandCyan)
            }
            .padding(.horizontal)
            
            // Question Card
            VStack(alignment: .leading, spacing: 20) {
                let currentQuestion = session.questions[currentQuestionIndex]
                
                Text(currentQuestion.q)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(spacing: 12) {
                    ForEach(0..<currentQuestion.options.count, id: \.self) { idx in
                        let opt = currentQuestion.options[idx]
                        let isSelected = selectedAnswers[currentQuestionIndex] == idx
                        
                        Button {
                            selectedAnswers[currentQuestionIndex] = idx
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(isSelected ? Theme.brandCyan : Color.white.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    
                                    if isSelected {
                                        Circle()
                                            .fill(Theme.brandCyan)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                
                                Text(opt)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Theme.brandCyan.opacity(0.08) : Color.white.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Theme.brandCyan.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            // Question navigation row (compact layout with back/forward arrow clicks)
            HStack(spacing: 12) {
                ForEach(0..<session.questions.count, id: \.self) { idx in
                    let isCurrent = idx == currentQuestionIndex
                    let isAnswered = selectedAnswers[idx] != -1
                    
                    Button {
                        currentQuestionIndex = idx
                    } label: {
                        Text("\(idx + 1)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(isCurrent ? .black : (isAnswered ? Theme.brandCyan : .white.opacity(0.5)))
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(isCurrent ? Theme.brandCyan : (isAnswered ? Theme.brandCyan.opacity(0.12) : Color.white.opacity(0.04)))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Theme.brandCyan, lineWidth: isCurrent ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            // Navigation Footer
            HStack(spacing: 12) {
                Button {
                    if currentQuestionIndex > 0 {
                        currentQuestionIndex -= 1
                    }
                } label: {
                    Text("BACK")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white.opacity(currentQuestionIndex > 0 ? 0.9 : 0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(currentQuestionIndex > 0 ? 0.25 : 0.08), lineWidth: 1)
                        )
                }
                .disabled(currentQuestionIndex == 0)
                
                if currentQuestionIndex < session.questions.count - 1 {
                    Button {
                        currentQuestionIndex += 1
                    } label: {
                        Text("NEXT")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.cardBorder)
                            )
                    }
                } else {
                    let allAnswered = !selectedAnswers.contains(-1)
                    
                    Button {
                        showSubmitConfirmation = true
                    } label: {
                        Text("SUBMIT EXAM")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        allAnswered
                                        ? LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                    )
                            )
                    }
                    .disabled(!allAnswered)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .alert("Submit Assessment?", isPresented: $showSubmitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Submit", role: .destructive) {
                Task {
                    await submitExam(session.attemptToken)
                }
            }
        } message: {
            Text("Are you sure you want to lock in your answers? This cannot be modified once submitted.")
        }
    }
    
    // MARK: - Graded View
    private func gradedView(_ result: KinesiologyAssessmentResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                if result.passed {
                    passingCelebrationView(result)
                } else {
                    failingView(result)
                }
            }
            .padding(.vertical, 24)
        }
        .background(Theme.deepBlack.ignoresSafeArea())
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                KinesiologyShareSheet(activityItems: [image])
            } else {
                Text("Certificate not loaded")
            }
        }
        .alert("Share System", isPresented: $showShareAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareAlertMessage)
        }
    }
    
    // MARK: - Premium Passing Celebration View
    private func passingCelebrationView(_ result: KinesiologyAssessmentResult) -> some View {
        VStack(spacing: 28) {
            // Gold Medal header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.2), Color(red: 1.0, green: 0.65, blue: 0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.3), radius: 15)
                
                Text("BOARD CERTIFIED")
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)
                
                Text("CONGRATULATIONS!")
                    .font(.system(.title, design: .monospaced).weight(.black))
                    .foregroundStyle(.white)
                
                Text("You passed the proctored examination and have been officially credentialed by the Applied Kinesiology Board.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Exam stats summary card
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("FINAL SCORE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(String(format: "%.1f%%", result.scorePct))
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .foregroundStyle(Theme.brandCyan)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .frame(height: 32)
                
                VStack(spacing: 4) {
                    Text("CORRECT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("\(result.correct) / \(result.total)")
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .frame(height: 32)
                
                VStack(spacing: 4) {
                    Text("XP AWARDED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("+500 XP")
                        .font(.system(.headline, design: .monospaced).weight(.bold))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
            .padding(.horizontal, 24)
            
            if let cert = claimedCertificate {
                VStack(spacing: 24) {
                    Text("DIGITAL CREDENTIAL CERTIFICATE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(2)
                    
                    // Render the Certificate view itself (can be rendered to image!)
                    KinesiologyCertificateView(cert: cert, score: result.scorePct)
                        .frame(maxWidth: 360)
                        .padding(.horizontal, 16)
                    
                    // Claim & Share Controls
                    VStack(spacing: 12) {
                        Button {
                            saveCertificateImage(cert: cert, score: result.scorePct)
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("SAVE CERTIFICATE TO PHOTOS")
                            }
                            .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Capsule().fill(Theme.brandCyan))
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                shareCertificateSystem(cert: cert, score: result.scorePct)
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("SHARE VIA...")
                                }
                                .font(.system(.caption, design: .monospaced, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            
                            Button {
                                Task {
                                    await shareToLabFeed(cert: cert, score: result.scorePct)
                                }
                            } label: {
                                HStack {
                                    if isSharingToFeed {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text("POST TO FEED")
                                }
                                .font(.system(.caption, design: .monospaced, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(RoundedRectangle(cornerRadius: 24).fill(Theme.elitePurple))
                            }
                            .disabled(isSharingToFeed)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                Button {
                    Task {
                        await claimCertificate()
                    }
                } label: {
                    HStack {
                        if isClaiming {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.8)
                                .padding(.trailing, 8)
                        }
                        Text("CLAIM BOARD CERTIFICATE")
                            .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing)
                        )
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .disabled(isClaiming)
            }
            
            Button {
                dismiss()
            } label: {
                Text("RETURN TO LAB")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding()
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Failing View
    private func failingView(_ result: KinesiologyAssessmentResult) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)
            
            Text("ASSESSMENT NOT PASSED")
                .font(.system(.caption, design: .monospaced).weight(.black))
                .foregroundStyle(.red)
                .tracking(3)
            
            Text("KINESIOLOGY STANDARD")
                .font(.system(.title3, design: .monospaced).weight(.black))
                .foregroundStyle(.white)
            
            VStack(spacing: 6) {
                Text(String(format: "Score: %.1f%%", result.scorePct))
                    .font(.system(.title3, design: .monospaced).weight(.heavy))
                    .foregroundStyle(.red)
                
                Text("\(result.correct) of \(result.total) correct answers")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            
            Text("A score of 80.0% is required for board credentialing. A study cooldown is now active. Review your course materials, study bio-digital anatomical overlays, and refine your biomechanical techniques before retrying.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .lineSpacing(4)
            
            Button {
                dismiss()
            } label: {
                Text("RETURN TO LAB")
                    .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Theme.cardBorder))
                    .padding(.horizontal, 48)
                    .padding(.top, 24)
            }
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("PROCTOR ERROR")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(.red)
            
            Text(message)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                dismiss()
            } label: {
                Text("DISMISS")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 140, height: 44)
                    .background(Capsule().fill(Theme.brandCyan))
            }
        }
    }
    
    // MARK: - API Calls
    private func startExam() async {
        state = .loading
        do {
            let session = try await service.startFinalAssessment()
            selectedAnswers = Array(repeating: -1, count: session.questions.count)
            currentQuestionIndex = 0
            
            // Parse expiration Date
            if let date = parseExpiresAt(session.expiresAt) {
                startTimer(expiration: date)
            } else {
                startTimer(expiration: Date().addingTimeInterval(900)) // Fallback 15 mins
            }
            
            state = .active(session)
        } catch {
            state = .error("Failed to start final assessment: \(error.localizedDescription)")
        }
    }
    
    private func submitExam(_ attemptToken: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        timer?.invalidate()
        do {
            let result = try await service.submitFinalAssessment(token: attemptToken, answers: selectedAnswers)
            isSubmitting = false
            state = .graded(result)
            FelToastCenter.shared.show("Assessment graded", isError: false)
        } catch {
            isSubmitting = false
            state = .error("Failed to submit assessment: \(error.localizedDescription)")
        }
    }
    
    private func claimCertificate() async {
        guard !isClaiming else { return }
        isClaiming = true
        do {
            let cert = try await service.claimCertificate()
            isClaiming = false
            claimedCertificate = cert
            FelToastCenter.shared.show("Credentials successfully claimed!", isError: false)
        } catch {
            isClaiming = false
            state = .error("Failed to claim credentials: \(error.localizedDescription)")
        }
    }
    
    private func startTimer(expiration: Date) {
        expirationDate = expiration
        timer?.invalidate()
        
        updateTimeRemaining(expiration: expiration)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining(expiration: expiration)
        }
    }
    
    private func updateTimeRemaining(expiration: Date) {
        let now = Date()
        guard now < expiration else {
            timeRemainingString = "00:00"
            timer?.invalidate()
            Task {
                if case .active(let session) = state {
                    // Force complete uncompleted answers with -1 (representing unanswered)
                    await submitExam(session.attemptToken)
                }
            }
            return
        }
        
        let interval = expiration.timeIntervalSince(now)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        timeRemainingString = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func parseExpiresAt(_ expiresAt: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: expiresAt) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        return fallback.date(from: expiresAt)
    }
    
    // MARK: - Share System & Feed Functions
    
    private func generateImage(cert: CertificateClaimResult, score: Double) -> UIImage? {
        let renderer = ImageRenderer(content: KinesiologyCertificateView(cert: cert, score: score).frame(width: 480, height: 600))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
    
    private func saveCertificateImage(cert: CertificateClaimResult, score: Double) {
        guard let uiImage = generateImage(cert: cert, score: score) else {
            shareAlertMessage = "Could not render certificate image."
            showShareAlert = true
            return
        }
        
        let imageSaver = ImageSaver { error in
            if let error = error {
                shareAlertMessage = "Failed to save: \(error.localizedDescription)"
            } else {
                shareAlertMessage = "Certificate saved to Photos successfully!"
            }
            showShareAlert = true
        }
        imageSaver.writeToPhotoAlbum(image: uiImage)
    }
    
    private func shareCertificateSystem(cert: CertificateClaimResult, score: Double) {
        guard let uiImage = generateImage(cert: cert, score: score) else {
            shareAlertMessage = "Could not render certificate image."
            showShareAlert = true
            return
        }
        shareImage = uiImage
        showShareSheet = true
    }
    
    private func shareToLabFeed(cert: CertificateClaimResult, score: Double) async {
        guard !isSharingToFeed else { return }
        isSharingToFeed = true
        defer { isSharingToFeed = false }
        
        do {
            let profile = SaveSystem.loadProfile()
            let name = profile.displayName.isEmpty ? "Athlete" : profile.displayName
            let certId = cert.certificateId ?? "N/A"
            
            try await TrainingLabSocialBridge.shared.publishKinesiologyCertification(
                athleteDisplayName: name,
                certificateId: certId,
                scorePct: score
            )
            
            FelToastCenter.shared.show("Certificate shared to social feed!", isError: false)
        } catch {
            shareAlertMessage = "Failed to share: \(error.localizedDescription)"
            showShareAlert = true
        }
    }
}

// MARK: - Premium SwiftUI Digital Certificate View
struct KinesiologyCertificateView: View {
    let cert: CertificateClaimResult
    let score: Double
    
    var body: some View {
        VStack(spacing: 20) {
            // Border layout
            VStack(spacing: 16) {
                // Header decoration
                HStack {
                    Image(systemName: "laurel.leading")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                    
                    Text("OFFICIAL CERTIFICATE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                        .tracking(3)
                    
                    Image(systemName: "laurel.trailing")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                }
                .padding(.top, 12)
                
                Text("APPLIED KINESIOLOGY BOARD")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .tracking(2)
                
                Text("This credential certifies that the athlete has successfully completed all coursework, achieved the mandatory PRQ score thresholds, and passed the proctored comprehensive exam in applied movement sciences, kinetic chain physics, and biomechanical optimization.")
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                
                Divider()
                    .background(Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.25))
                    .padding(.horizontal, 32)
                
                VStack(spacing: 4) {
                    Text("ATHLETE CREDENTIALED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)
                    
                    let profileName = SaveSystem.loadProfile().displayName
                    Text(profileName.isEmpty ? "LAB ATHLETE" : profileName.uppercased())
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.vertical, 2)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CREDENTIAL STATUS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("ACTIVE & VERIFIED")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("EXAM SCORE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(String(format: "%.1f%% PASS", score))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Custom Border, gold seals, and monospaced credential IDs
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("CREDENTIAL ID:")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(cert.certificateId ?? "FEL-AK-PENDING")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        
                        HStack(spacing: 8) {
                            Text("VERIFIED ON:")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(cert.issuedAt ?? "N/A")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("CHAIN HASH :")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(cert.credential ?? "0x00000000000000000000")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 16)
                }
                
                // Gold Seal Footer
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color(red: 1.0, green: 0.9, blue: 0.4), Color(red: 0.8, green: 0.55, blue: 0.1)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 20
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .shadow(radius: 4)
                            
                            Image(systemName: "seal.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                        }
                        
                        Text("GOLD STANDARD")
                            .font(.system(size: 6, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.2), Color(red: 0.8, green: 0.55, blue: 0.1), Color(red: 1.0, green: 0.85, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
            )
            .padding(8)
        }
        .background(Color.black)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Utilities

class ImageSaver: NSObject {
    var completion: (Error?) -> Void
    
    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }
    
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion(error)
    }
}

struct KinesiologyShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
