import SwiftUI

struct CritiqueRequestView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedExercise: String = ""
    @State private var notesText: String = ""
    @State private var showConfirmation: Bool = false
    @State private var showInsufficientCredits: Bool = false
    @State private var showReviewSheet: CritiqueRequest?
    @State private var reviewRating: Double = 4.0

    private let exerciseOptions = [
        "Dunk Approach", "Vertical Jump", "Sprint Mechanics",
        "Depth Drop", "Box Jump", "Lateral Leap",
        "Ankle Dorsiflexion", "Hip Extension", "Landing Mechanics"
    ]

    private var pendingRequests: [CritiqueRequest] {
        viewModel.critiqueRequests.filter { $0.status == .pending }
    }

    private var completedRequests: [CritiqueRequest] {
        viewModel.critiqueRequests.filter { $0.status == .completed }
    }

    private var reviewedRequests: [CritiqueRequest] {
        viewModel.critiqueRequests.filter { $0.status == .rated }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    costBanner
                    exerciseSelector
                    notesSection
                    submitButton

                    if !completedRequests.isEmpty {
                        readyForReviewSection
                    }
                    if !pendingRequests.isEmpty {
                        pendingSection
                    }
                    if !reviewedRequests.isEmpty {
                        historySection
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Request Critique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .overlay {
                if showConfirmation {
                    confirmationOverlay
                }
            }
            .alert("Insufficient Credits", isPresented: $showInsufficientCredits) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You need \(LabViewModel.critiqueCostCredits) credits. Purchase more credits to request IRL critiques.")
            }
            .sheet(item: $showReviewSheet) { request in
                CritiqueReviewSheet(
                    request: request,
                    rating: $reviewRating
                ) {
                    viewModel.reviewCritique(requestId: request.id, rating: reviewRating)
                    showReviewSheet = nil
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.deepBlack)
    }

    private var costBanner: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRO MOVEMENT CRITIQUE")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)

                    Text("Get expert analysis of your form")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.brandCyan)
                        Text("\(LabViewModel.critiqueCostCredits)")
                            .font(.system(.title3, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Text("COST")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(2)
                }
            }

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("YOUR BALANCE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.brandCyan)
                        Text("\(viewModel.profile.premiumCredits)")
                            .font(.system(.headline, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))

                VStack(spacing: 2) {
                    Text("ESCROW HELD")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                        Text("\(viewModel.coachEconomy.pendingCredits)")
                            .font(.system(.headline, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))

                VStack(spacing: 2) {
                    Text("CRITIQUES")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                    Text("\(viewModel.critiqueRequests.count)")
                        .font(.system(.headline, design: .monospaced, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var exerciseSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MOVEMENT TO CRITIQUE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(exerciseOptions, id: \.self) { exercise in
                    Button {
                        selectedExercise = exercise
                    } label: {
                        Text(exercise.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(selectedExercise == exercise ? .black : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(selectedExercise == exercise ? Theme.brandCyan : Theme.cardBackground)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES FOR COACH")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            TextEditor(text: $notesText)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.cardBorder, lineWidth: 0.5)
                        )
                )

            Text("Describe what you want analyzed (e.g., \"Check my ankle stiffness on the load phase\")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var submitButton: some View {
        Button {
            guard !selectedExercise.isEmpty else { return }
            if viewModel.profile.premiumCredits < LabViewModel.critiqueCostCredits {
                showInsufficientCredits = true
                return
            }
            if let requestId = viewModel.requestCritiqueWithRequestId(exerciseName: selectedExercise, notes: notesText) {
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.simulateCoachResponse(requestId: requestId)
                }
                withAnimation(.spring(response: 0.4)) {
                    showConfirmation = true
                }
            } else {
                showInsufficientCredits = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 12))
                Text("REQUEST CRITIQUE \u{2014} \(LabViewModel.critiqueCostCredits) CREDITS")
            }
            .font(.system(.subheadline, design: .monospaced, weight: .black))
            .foregroundStyle(canSubmit ? .black : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? Theme.brandCyan : Color.white.opacity(0.06))
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(!canSubmit)
        .sensoryFeedback(.success, trigger: showConfirmation)
    }

    private var canSubmit: Bool {
        !selectedExercise.isEmpty
    }

    private var readyForReviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text("READY FOR REVIEW")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.green)
                    .tracking(2)
            }

            ForEach(completedRequests) { request in
                Button {
                    showReviewSheet = request
                } label: {
                    CritiqueRequestRow(request: request, showReviewBadge: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("PENDING")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.orange)
                    .tracking(2)
            }

            ForEach(pendingRequests) { request in
                CritiqueRequestRow(request: request, showReviewBadge: false)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REVIEWED")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(2)

            ForEach(reviewedRequests) { request in
                CritiqueRequestRow(request: request, showReviewBadge: false)
            }
        }
    }

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.brandCyan)
                        .symbolEffect(.bounce, value: showConfirmation)
                }

                Text("CRITIQUE REQUESTED")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.brandCyan)
                        Text("\(LabViewModel.critiqueCostCredits) credits deducted")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("Held in escrow until you review")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.orange)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.brandBlue)
                        Text("+\(LabViewModel.critiqueEngagementShardBonus) shard engagement bonus")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                    }
                }

                Text("A coach will analyze your \(selectedExercise) and provide detailed feedback with telestrator annotations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showConfirmation = false
                    }
                    selectedExercise = ""
                    notesText = ""
                } label: {
                    Text("DONE")
                        .font(.system(.subheadline, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(Theme.brandCyan)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
        }
        .transition(.opacity)
    }
}

struct CritiqueRequestRow: View {
    let request: CritiqueRequest
    let showReviewBadge: Bool

    private var statusColor: Color {
        switch request.status {
        case .pending: .orange
        case .inProgress: Theme.brandBlue
        case .completed: .green
        case .rated: .secondary
        case .cancelled: .gray
        case .disputed: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.exerciseName.uppercased())
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)

                    Text(request.requestDate, style: .relative)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(request.status.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
            }

            if let response = request.coachResponse {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                        Text(response.coachName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)

                        Text(response.overallGrade)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(gradeColor(response.overallGrade))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(gradeColor(response.overallGrade).opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(response.textFeedback)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if !response.focusAreas.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(response.focusAreas, id: \.self) { area in
                                Text(area.uppercased())
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.brandCyan.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Theme.brandCyan.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.02))
                )
            }

            if showReviewBadge {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("TAP TO REVIEW & RELEASE ESCROW")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.08))
                .clipShape(.rect(cornerRadius: 8))
            }

            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.brandCyan)
                Text("\(request.creditsCost) credits")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(showReviewBadge ? Color.green.opacity(0.2) : Theme.cardBorder, lineWidth: 0.5)
                )
        )
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "ELITE": Theme.elitePurple
        case "PRIMED": Theme.brandBlue
        case "DEVELOPING": .orange
        default: Theme.foundationGreen
        }
    }
}

struct CritiqueReviewSheet: View {
    let request: CritiqueRequest
    @Binding var rating: Double
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let response = request.coachResponse {
                        feedbackDetail(response)
                    }
                    ratingSection
                    releaseButton
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Review Critique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.deepBlack)
    }

    private func feedbackDetail(_ response: CritiqueResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COACH FEEDBACK")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)

                    Text(request.exerciseName.uppercased())
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(response.overallGrade)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(gradeColor(response.overallGrade).opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(response.textFeedback)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)

            if !response.focusAreas.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FOCUS AREAS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)

                    HStack(spacing: 6) {
                        ForEach(response.focusAreas, id: \.self) { area in
                            Text(area.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.brandCyan.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brandCyan)
                Text(response.coachName)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                Text("\u{2022}")
                    .foregroundStyle(.tertiary)
                Text(response.responseDate, style: .relative)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var ratingSection: some View {
        VStack(spacing: 12) {
            Text("RATE THIS CRITIQUE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            rating = Double(star)
                        }
                    } label: {
                        Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(Double(star) <= rating ? .yellow : .secondary)
                    }
                }
            }
        }
    }

    private var releaseButton: some View {
        VStack(spacing: 8) {
            Button {
                onConfirm()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 12))
                    Text("RELEASE \(request.creditsCost) CREDITS TO COACH")
                }
                .font(.system(.subheadline, design: .monospaced, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.foundationGreen)
                .clipShape(.rect(cornerRadius: 14))
            }

            Text("Credits will be released from escrow to the coach")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "ELITE": Theme.elitePurple
        case "PRIMED": Theme.brandBlue
        case "DEVELOPING": .orange
        default: Theme.foundationGreen
        }
    }
}
