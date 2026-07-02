import SwiftUI

/// Natural-language arena authoring — dispatches `fel.generate.from_text` to the NEXUS gameplay bridge.
struct DescribeArenaView: View {
    @State private var prompt = ""
    @State private var progressLines: [String] = []
    @State private var isGenerating = false
    @State private var lastIntent = ""
    @State private var lastJobCount = 0
    @State private var engine = NexusGameplayEngine()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.nexusGenerate)

                Text("Describe your arena")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.brandCyan)

                Text("Natural language is parsed into voxel edits and procedural mesh jobs. No API key required.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField(
                    "e.g. Beach court with sand dune center and orange hoops",
                    text: $prompt,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("DescribeArenaPromptField")

                Button(action: generateArena) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isGenerating ? "Generating…" : "Generate arena")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandCyan)
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                .accessibilityIdentifier("DescribeArenaGenerateButton")

                if !lastIntent.isEmpty {
                    Label("Intent: \(lastIntent)", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.elitePurple)
                }

                if lastJobCount > 0 {
                    Text("\(lastJobCount) mesh job(s) queued · import via scripts/nexus_import_assets.py for external exports")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !progressLines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .font(.headline)
                        ForEach(Array(progressLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .background(Theme.deepBlack)
        .onAppear {
            if !engine.isLinked {
                engine.bootstrapForCreativeCommands()
            }
        }
    }

    private func generateArena() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isGenerating = true
        progressLines = ["Parsing prompt…"]

        Task { @MainActor in
            defer { isGenerating = false }

            if let preview = await engine.parseArenaPrompt(trimmed) {
                lastIntent = preview.intent
                progressLines.append("Plan: \(preview.stepCount) step(s) · \(preview.intent)")
            }

            progressLines.append("Executing generative plan…")
            let result = await engine.describeArena(trimmed)

            if result.success {
                lastIntent = result.intent
                lastJobCount = result.jobCount
                progressLines.append(result.summary)
                if result.jobCount > 0 {
                    progressLines.append("Mesh jobs complete — check assets/nexus/imported/")
                }
            } else {
                progressLines.append("Error: \(result.errorMessage ?? "generation failed")")
            }
        }
    }
}

#Preview {
    DescribeArenaView()
}
