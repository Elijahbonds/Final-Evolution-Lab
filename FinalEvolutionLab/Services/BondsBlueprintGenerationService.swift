import Foundation

struct BondsBlueprintGenerationService: Sendable {
    private let curatedBondsBounceYouTubeURLs: [String] = [
        "https://youtu.be/hrlGbS0r-hM?si=01FQQ8_l0NX9RLh_",
        "https://youtu.be/dAoLYThf1bc?si=2M61Z9g7rTRKXmb5",
        "https://youtu.be/q1HLjLbhS2s?si=abxLi2CgxMgmUH_U",
        "https://youtu.be/pqyxTY85x4U?si=vi02sr7W835uROpO",
        "https://youtu.be/J037GG99GT0?si=3ZkOauSg8WzWMVu0",
    ]

    func defaultModelProfile(from profile: UserProfile, cloneProfile: CloneProfile) -> BondsAIModelProfile {
        let display = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = display.isEmpty ? "Bonds Athlete" : display
        let modelName = "\(owner) AI Coach"
        let now = Date()
        return BondsAIModelProfile(
            id: BondsAIModelProfile.makeId(userId: profile.id),
            modelDisplayName: modelName,
            ownerDisplayName: owner,
            cloneId: cloneProfile.cloneId,
            consentForLikeness: true,
            consentForVoice: true,
            useForFitnessEducationTracks: true,
            defaultNarrativeShot: .midShotTalkingHead,
            voiceProfile: .bondsDefault,
            createdAt: now,
            updatedAt: now
        )
    }

    func sanitizeYouTubeSources(_ rawURLs: [String]) -> [BlueprintSourceAsset] {
        rawURLs
            .compactMap { normalizeYouTubeURL($0) }
            .map { normalized in
                BlueprintSourceAsset(
                    id: BlueprintSourceAsset.makeId(url: normalized),
                    sourceType: .youtube,
                    sourceURL: normalized,
                    title: inferTitle(from: normalized),
                    notes: "Source reference for recreation + revision",
                    importedAt: Date()
                )
            }
    }

    func curatedBondsBounceSourceAssets() -> [BlueprintSourceAsset] {
        sanitizeYouTubeSources(curatedBondsBounceYouTubeURLs)
    }

    func createProject(
        track: TrainingTrack,
        equipment: EquipmentType,
        model: BondsAIModelProfile,
        sourceAssets: [BlueprintSourceAsset],
        revisionFocus: String
    ) -> BondsBlueprintProject {
        let program = TrainingProgramData.program(for: track, equipment: equipment)
        let dayFocus = Array(program.days.prefix(3))
        let allSourceIds = sourceAssets.map(\.id)
        var beats: [NarrativeDemoBeat] = []

        beats.append(
            NarrativeDemoBeat(
                id: "intro_\(track.rawValue)",
                title: "Blueprint intro",
                cameraShot: .midShotTalkingHead,
                narrationText: introScript(
                    ownerName: model.ownerDisplayName,
                    track: track,
                    revisionFocus: revisionFocus
                ),
                demoExerciseIds: [],
                sourceAssetIds: allSourceIds,
                estimatedDurationSeconds: 20
            )
        )

        for day in dayFocus {
            let exerciseFocus = Array(day.allExercises.prefix(3))
            let exerciseNames = exerciseFocus.map(\.name)
            let cueBlock = exerciseFocus.map { "\($0.name): \($0.cues)" }.joined(separator: " ")
            let narration = """
            In this \(day.title) segment, we rebuild the movement from the source footage and improve execution. \
            Focus points: \(exerciseNames.joined(separator: ", ")). \
            Coaching cues: \(cueBlock) \
            Revision emphasis: \(revisionFocus).
            """
            beats.append(
                NarrativeDemoBeat(
                    id: "day_\(day.id)",
                    title: day.title,
                    cameraShot: .midShotTalkingHead,
                    narrationText: narration,
                    demoExerciseIds: exerciseFocus.map(\.id),
                    sourceAssetIds: allSourceIds,
                    estimatedDurationSeconds: 30
                )
            )
        }

        beats.append(
            NarrativeDemoBeat(
                id: "outro_\(track.rawValue)",
                title: "Progression + call to action",
                cameraShot: .midShotTalkingHead,
                narrationText: """
                That is the Bonds Bounce blueprint revision pass. \
                Re-run these drills on your next session, then compare your rep quality against this AI recreation. \
                Keep this model active for every fitness education track so your coaching voice and demo style stay consistent.
                """,
                demoExerciseIds: [],
                sourceAssetIds: allSourceIds,
                estimatedDurationSeconds: 18
            )
        )

        return BondsBlueprintProject(
            id: BondsBlueprintProject.makeId(track: track),
            title: "Bonds Bounce \(track.rawValue) Blueprint",
            track: track,
            equipment: equipment,
            revisionFocus: revisionFocus,
            sourceAssetIds: allSourceIds,
            beats: beats,
            voiceProfile: model.voiceProfile,
            generatedAt: Date()
        )
    }

    private func introScript(ownerName: String, track: TrainingTrack, revisionFocus: String) -> String {
        """
        What’s up team — this is \(ownerName) AI. \
        We’re recreating the Bonds Bounce blueprint for the \(track.rawValue) track. \
        Today’s revision target is \(revisionFocus). \
        I’ll coach this in a mid-shot narrative so you can follow movement intent and technique in real time.
        """
    }

    private func normalizeYouTubeURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased() else {
            return nil
        }
        let supportedHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "www.youtu.be"]
        guard supportedHosts.contains(host) else { return nil }
        return url.absoluteString
    }

    private func inferTitle(from urlString: String) -> String {
        if let components = URLComponents(string: urlString),
           let id = components.queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
            return "YouTube Source \(id)"
        }
        if let url = URL(string: urlString), !url.lastPathComponent.isEmpty {
            return "YouTube Source \(url.lastPathComponent)"
        }
        return "YouTube Source"
    }
}
