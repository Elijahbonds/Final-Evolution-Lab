# Academy + Final Evolution Blueprint

Condensed implementation target for the education/gameplay fusion:

## 1) Character Creation (IRL Avatar)

- Source of truth: `SystemScanResult`
- Output: `AvatarSkinConfig` + `irlAvatarArchetype`
- Behavior:
  - Vertical + flight metrics scale avatar height/limb profile.
  - PRQ + sport bias adjust build, aura, and style identity.
  - Archetypes: `High Flyer`, `Power Driver`, `Agile Creator`, `Balanced Athlete`.

## 2) Core Sports Experience DNA

Implemented as game-mode metadata (`GameModeId.gameplayDNA`) with design intent:

- Basketball:
  - 1v1 = NBA 2K style pacing
  - 3v3 = NBA Street team flow
  - Dunk Contest = NBA Live 06 x NBA Street trick/special cadence
- Fighting:
  - Matrix Revolutions cinematic timing x Naruto Storm combo chaining
- Football:
  - Kick Return x NFL Street 3v3 lane chaos
- Volleyball/Tennis:
  - Wii Sports / Switch Resort readability and rally rhythm
- Baseball:
  - Home Run Derby timing and simplicity (Wii-style)
- Soccer:
  - FIFA Street 2 flair x Switch Resort accessibility
- Golf:
  - Wii Sports precision swing cadence
- Brain Brawl:
  - Big Brain Academy speed + Coursebox AI adaptation

## 3) Controls Contract

- Global rule: gameplay interactions must be operable with either:
  - `controller`
  - `swipe`
- Encoded in: `GameModeId.supportedInputs`

## 4) Education + Endgame Layer

Added model primitives (`Models/AcademyEvolution.swift`) for:

- Mentor Personas:
  - Magnus (STEM/Logic)
  - Lady Elara (Humanities/Arts)
  - Sarge Jax (Strategy/Leadership)
- Knowledge node progression and mental combine calibration
- Brain Brawl rulebook:
  - Wagers, sabotage rules, sponsorship perks
- Prestige Evolutions:
  - Technomancer, Lore-Walker, Grand Strategist
- Omni-Evolution unlock state:
  - all three trees at 100% mastery
  - custom challenge count + passive tax tracking
