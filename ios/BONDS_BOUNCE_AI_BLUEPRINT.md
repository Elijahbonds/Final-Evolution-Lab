# Bonds Bounce AI Blueprint Creator

This module scaffolds an **AI model + voice + demo narrative pipeline** for Bonds Bounce recreation and revision.

## What is generated

- **Personal AI model profile** (`BondsAIModelProfile`)
  - Likeness + voice consent flags
  - Voice style metadata (locale, tone, speaking rate, pitch)
  - Mid-shot talking-head narrative default
- **Source library** (`BlueprintSourceAsset`)
  - YouTube links are accepted as recreation references
  - Legacy references are retained as source metadata
- **Video project plan** (`BondsBlueprintProject`)
  - Track-aware beats for Foundations / Flight / Elite
  - Mid-shot narrative script with demo exercise mapping
  - Revision/improvement focus baked into narration

## Core runtime APIs

Implemented in `LabViewModel`:

- `ingestYouTubeBlueprintSources(_ urls: [String]) -> Int`
- `configureBondsAIModel(...)`
- `generateBondsBlueprintProject(track:equipment:revisionFocus:)`
- `activateBondsProject(projectId:)`
- `activeBondsBlueprintProject`
- `activeBondsNarrationScript`

## Persistence + cloud sync

`BondsAIStudioState` is persisted via:

- Local `SaveSystem` key: `finalEvolution_bondsAIStudio`
- Cloud snapshot (`CloudAppSnapshot`) as `bondsAIStudio`

## Example usage

```swift
let inserted = viewModel.ingestYouTubeBlueprintSources([
    "https://www.youtube.com/watch?v=abc123xyz",
    "https://youtu.be/qwe987"
])

viewModel.configureBondsAIModel(
    modelDisplayName: "Bonds AI Coach",
    voiceDisplayName: "Bonds Voice",
    toneStyle: "confident, technical, motivating"
)

let project = viewModel.generateBondsBlueprintProject(
    track: .flight,
    equipment: .movementEducation,
    revisionFocus: "cleaner footwork timing, takeoff mechanics, and landing control"
)

let narrationScript = viewModel.activeBondsNarrationScript
```

## Notes

- This scaffold generates **plans and scripts** for AI video recreation.
- You can plug this into your preferred video/voice synthesis stack for final rendering.
