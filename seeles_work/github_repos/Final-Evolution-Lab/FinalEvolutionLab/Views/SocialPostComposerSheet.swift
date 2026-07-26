import SwiftUI

struct SocialPostComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: SocialFeedDraft

    @State private var content: String = ""
    @State private var isPosting = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Share your win", text: $content, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Arena feed")
                }

                if let gameModeId = draft.gameModeId {
                    LabeledContent("Mode", value: gameModeId.replacingOccurrences(of: "_", with: " "))
                }
                if let score = draft.trainingScore {
                    LabeledContent("Score", value: String(format: "%.1f", score))
                }
                if let clip = draft.clipUrl, !clip.isEmpty {
                    LabeledContent("Clip", value: clip)
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Post to feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        SocialShareCoordinator.shared.dismissComposer()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { await post() }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                    .foregroundStyle(Theme.brandBlue)
                }
            }
            .onAppear {
                if content.isEmpty {
                    content = draft.content
                }
            }
        }
        .presentationBackground(Theme.deepBlack)
    }

    private func post() async {
        isPosting = true
        errorText = nil
        defer { isPosting = false }
        do {
            let author = try await TrainingLabSocialBridge.shared.ensureSqlUserRegistration(displayName: nil)
            try await TrainingLabSocialBridge.shared.createFeedPost(
                content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                authorId: author,
                gameModeId: draft.gameModeId,
                trainingScore: draft.trainingScore,
                clipUrl: draft.clipUrl,
                feedSource: draft.feedSource
            )
            SocialShareCoordinator.shared.dismissComposer()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
