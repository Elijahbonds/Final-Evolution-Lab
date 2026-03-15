import SwiftUI

struct OnboardingView: View {
    let onComplete: (String, Int, String) -> Void

    @State private var step: Int = 0
    @State private var selectedSport: String = ""
    @State private var age: Int = 16
    @State private var selectedGoal: String = ""
    @State private var appeared = false

    private let sports = [
        ("Basketball", "basketball.fill"),
        ("Football", "football.fill"),
        ("Soccer", "soccerball"),
        ("Baseball", "baseball.fill"),
        ("Track & Field", "figure.run"),
        ("Volleyball", "volleyball.fill"),
        ("Gymnastics", "figure.gymnastics"),
        ("Combat Sports", "figure.martial.arts"),
        ("Golf", "figure.golf"),
        ("Other", "sportscourt.fill"),
    ]

    private let goals = [
        ("Jump Higher", "arrow.up.circle.fill"),
        ("Get Faster", "bolt.circle.fill"),
        ("Build Power", "flame.circle.fill"),
        ("Move Better", "figure.flexibility"),
        ("Game Ready", "trophy.circle.fill"),
        ("Stay Healthy", "heart.circle.fill"),
    ]

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            Theme.meshGradient.opacity(0.3).ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 60)
                    .padding(.horizontal)

                Spacer()

                Group {
                    switch step {
                    case 0: sportSelection
                    case 1: ageSelection
                    case 2: goalSelection
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                nextButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.brandBlue : Color.white.opacity(0.08))
                    .frame(height: 4)
            }
        }
    }

    private var sportSelection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("WHAT'S YOUR SPORT?")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue)
                    .tracking(3)

                Text("Choose Your\nDiscipline")
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Delete the fear. Your movement, audited.")
                    .font(.caption)
                    .foregroundStyle(Theme.brandBlue.opacity(0.9))
                    .padding(.top, 4)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(sports, id: \.0) { sport, icon in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedSport = sport }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(selectedSport == sport ? Theme.brandBlue : .secondary)
                                .frame(width: 24)

                            Text(sport.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(selectedSport == sport ? .white : .secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedSport == sport ? Theme.brandBlue.opacity(0.12) : Theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedSport == sport ? Theme.brandBlue.opacity(0.4) : Theme.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var ageSelection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("HOW OLD ARE YOU?")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue)
                    .tracking(3)

                Text("Set Your\nProfile")
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Text("\(age)")
                    .font(.system(size: 72, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("YEARS OLD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(3)
            }

            Picker("Age", selection: $age) {
                ForEach(8...65, id: \.self) { a in
                    Text("\(a)").tag(a)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
            .clipShape(.rect(cornerRadius: 16))
        }
        .padding(.horizontal, 24)
    }

    private var goalSelection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("WHAT'S YOUR GOAL?")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue)
                    .tracking(3)

                Text("Define Your\nEvolution")
                    .font(.system(size: 36, weight: .black))
                    .italic()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ForEach(goals, id: \.0) { goal, icon in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedGoal = goal }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(selectedGoal == goal ? Theme.brandBlue : .secondary)
                                .frame(width: 28)

                            Text(goal.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(selectedGoal == goal ? .white : .secondary)

                            Spacer()

                            if selectedGoal == goal {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.brandBlue)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedGoal == goal ? Theme.brandBlue.opacity(0.12) : Theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedGoal == goal ? Theme.brandBlue.opacity(0.4) : Theme.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: !selectedSport.isEmpty
        case 1: true
        case 2: !selectedGoal.isEmpty
        default: false
        }
    }

    private var nextButton: some View {
        Button {
            if step < 2 {
                withAnimation(.spring(response: 0.4)) { step += 1 }
            } else {
                onComplete(selectedSport, age, selectedGoal)
            }
        } label: {
            HStack(spacing: 8) {
                Text(step < 2 ? "CONTINUE" : "START EVOLUTION")
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                if step == 2 {
                    Image(systemName: "bolt.fill")
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canAdvance ? Theme.brandBlue : Theme.brandBlue.opacity(0.3))
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(!canAdvance)
        .sensoryFeedback(.impact(weight: .medium), trigger: step)
    }
}
