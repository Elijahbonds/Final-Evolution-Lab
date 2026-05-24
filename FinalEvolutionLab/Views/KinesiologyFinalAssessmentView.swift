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
    @State private var timeRemainingString: String = "00:00"
    @State private var timer: Timer?
    @State private var expirationDate: Date?
    
    @State private var isSubmitting = false
    @State private var showSubmitConfirmation = false
    
    @State private var isClaiming = false
    @State private var claimedCertificate: CertificateClaimResult?
    
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
                        Text("2-hour active window. Session automatically expires.")
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
            
            // Question index circles
            HStack(spacing: 8) {
                ForEach(0..<session.questions.count, id: \.self) { idx in
                    let isCurrent = idx == currentQuestionIndex
                    let isAnswered = selectedAnswers[idx] != -1
                    
                    Circle()
                        .fill(isCurrent ? Theme.brandCyan : (isAnswered ? Theme.brandCyan.opacity(0.4) : Color.white.opacity(0.1)))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Theme.brandCyan, lineWidth: isCurrent ? 2 : 0)
                                .scaleEffect(isCurrent ? 1.5 : 1)
                        )
                        .onTapGesture {
                            currentQuestionIndex = idx
                        }
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
                        Text("SUBMIT")
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
        VStack(spacing: 24) {
            Spacer()
            
            if result.passed {
                Image(systemName: "medal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.2), Color(red: 1.0, green: 0.65, blue: 0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Theme.brandCyan.opacity(0.3), radius: 15)
                
                Text("BOARD CERTIFIED")
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(4)
                
                Text("APPLIED KINESIOLOGY")
                    .font(.system(.title2, design: .monospaced).weight(.black))
                    .foregroundStyle(.white)
                
                VStack(spacing: 6) {
                    Text(String(format: "Score: %.1f%%", result.scorePct))
                        .font(.system(.title3, design: .monospaced).weight(.heavy))
                        .foregroundStyle(Theme.brandCyan)
                    
                    Text("\(result.correct) of \(result.total) answers correct")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.top, 4)
                
                if let cert = claimedCertificate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VERIFICATION ID")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(cert.certificateId ?? "N/A")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("ISSUED AT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 4)
                        Text(cert.issuedAt ?? "N/A")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Text("CREDENTIAL RECEIPT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 4)
                        Text(cert.credential ?? "N/A")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .lineLimit(1)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
                    .padding(.horizontal, 24)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("RETURN TO LAB")
                            .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Capsule().fill(Theme.brandCyan))
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
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
            } else {
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
                
                Text("A score of 80.0% is required for board credentialing. A 5-minute study cooldown is now active. Review course materials and bio-digital overlays before retrying.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                
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
            
            Spacer()
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
                // If parsing fails, fall back to 2 hours from now
                startTimer(expiration: Date().addingTimeInterval(7200))
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
        
        // Initial tick
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
            // Auto submit or expire exam if appropriate
            Task {
                if case .active(let session) = state {
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
}
