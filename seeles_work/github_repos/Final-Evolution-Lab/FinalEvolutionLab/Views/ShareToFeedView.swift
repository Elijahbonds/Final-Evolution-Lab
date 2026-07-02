import SwiftUI

struct ShareToFeedView: View {
    let viewModel: LabViewModel
    @State private var screenshot: UIImage?
    @State private var isCapturing: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var captionText: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                previewCard
                captionSection
                shareButton
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.slateBackground)
        .sheet(isPresented: $showShareSheet) {
            if let items = shareItems {
                ActivityViewRepresentable(activityItems: items)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SHARE TO FEED")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.neonGreen)
                .tracking(4)

            Text("Post")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var previewCard: some View {
        VStack(spacing: 0) {
            if let screenshot {
                Image(uiImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
            } else {
                socialPostLayout
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Theme.neonGreen.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var socialPostLayout: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.neonGreen.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: viewModel.profile.avatarSystemName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.neonGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.profile.displayName)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                    Text(viewModel.profile.athleteTag)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(Int(viewModel.effectiveMetrics.prqScore))")
                        .font(.system(size: 40, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("PRQ SCORE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                        .tracking(2)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 50)

                VStack(spacing: 4) {
                    Text(viewModel.userPRQTier.rawValue)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(tierColor)
                    Text("TIER")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(2)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 50)

                VStack(spacing: 4) {
                    Text("\(viewModel.profile.totalWorkouts)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("SESSIONS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(2)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
            )

            HStack {
                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.neonGreen)
                Text("FINAL EVOLUTION LAB")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(2)
            }
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTION")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)

            TextField("Share your evolution...", text: $captionText, axis: .vertical)
                .font(.system(.body))
                .foregroundStyle(.white)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.slateCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
    }

    private var shareButton: some View {
        VStack(spacing: 12) {
            Button {
                captureAndShare()
            } label: {
                HStack(spacing: 8) {
                    if isCapturing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text("SHARE TO FEED")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.neonGreen)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(isCapturing)

            Button {
                screenshot = UnityManager.shared.takeScreenshot()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 12, weight: .semibold))
                    Text("CAPTURE TRAINING VIEW")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(Theme.neonGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.neonGreen.opacity(0.08))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    private func captureAndShare() {
        isCapturing = true
        if screenshot == nil {
            screenshot = UnityManager.shared.takeScreenshot()
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isCapturing = false
            showShareSheet = true
        }
    }

    private var shareItems: [Any]? {
        var items: [Any] = []
        let text = captionText.isEmpty
            ? "PRQ: \(Int(viewModel.effectiveMetrics.prqScore)) | \(viewModel.userPRQTier.rawValue) | Final Evolution Lab"
            : "\(captionText)\n\nPRQ: \(Int(viewModel.effectiveMetrics.prqScore)) | \(viewModel.userPRQTier.rawValue)"
        items.append(text)
        if let screenshot {
            items.append(screenshot)
        }
        return items.isEmpty ? nil : items
    }

    private var tierColor: Color {
        switch viewModel.userPRQTier {
        case .diamond: .yellow
        case .platinum: Theme.elitePurple
        case .gold: .orange
        case .silver: Theme.brandBlue
        case .bronze: Theme.neonGreen
        case .unranked: .gray
        }
    }
}

struct ActivityViewRepresentable: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
