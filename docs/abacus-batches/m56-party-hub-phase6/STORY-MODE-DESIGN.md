# FEL STORY MODE — design pass (Phase 6 deliverable: the plan, before any code)

Story Mode is the least-defined item on the whole backlog — "story mode?
gameplay? cutscenes? interactions" — so per the 10-phase plan, Phase 6
delivers the DESIGN, for approval, before any code batch builds it. This is
that design. It is deliberately built from what FEL already owns: every
chapter is an existing, already-shipped mode with a modified win condition,
and every "cutscene" is a tech we can ship procedurally (no video, no new
art assets, no licensed anything).

## The loop: a season, not a movie
**"THE RUN" — one hungry season to go from nobody to Final Evolution
champion.** The player character is the hero avatar they already have.
Structure: 10 chapters, each = pre-chapter dialogue card(s) → one mode
session with a chapter-specific win condition → post-chapter dialogue +
reward. A chapter takes 3-6 minutes; the season is a ~45-minute arc with
replayable chapters.

## Original cast (no likenesses, no franchise anything)
- **COACH RHEA** — your corner. Opens every chapter, sets the stakes,
  delivers the tutorial beat in-fiction.
- **VEX** — the courts rival (basketball/dunk chapters). Cocky, technical.
- **KITE** — the parks rival (skate/snow/surf chapters). Laid-back, fearless.
- **MARA SENSEI** — the dojo rival (combat chapters). Formal, unreadable.
- **THE JUDGES** (Silk/Doc/Prime, already in the game) — recurring color
  commentary between acts.
Rivals appear IN their chapters using the existing character pipeline
(tinted spawns, same rig) — they are already effectively in the game today
as "rival" bodies; the story names them and gives them voice via text.

## The 10 chapters (every one an existing mode + a twist)
| Ch | Title | Mode (exists today) | Twist / win condition |
|---|---|---|---|
| 1 | First Light | Beach Sprint | Tutorial-in-fiction; beat Rhea's time |
| 2 | Court Rat | 1v1 Hoops | Beat Vex to 7 (short game, high pressure) |
| 3 | The Bag | Karate Endless | Survive 3 waves with Mara watching (no ally) |
| 4 | Park Legend | Skate Run | Hit a target score with the downhill+bowl lines called out |
| 5 | Cold Shoulder | Snowboard Slalom | Finish with 8+ gates AND clear the Yeti |
| 6 | Ring Discipline | Karate VS | Beat Mara Sensei best-of-3 |
| 7 | The Carnival | Court Carnival | Take the champion crown (random 4 events) |
| 8 | Street Ball | 3v3 Streetball | Win with 3+ assists (team play beat) |
| 9 | The Edge | Mixed Combat | Beat Kite — win at least one round BY RING-OUT |
| 10 | Final Evolution | Dunk Contest | Beat Vex in the judged final; 27+ on the last dunk = golden ending card |

## Cutscene tech (all buildable with owned systems)
1. **Dialogue cards** — a `StoryDialogue` overlay: character name plate,
   tinted portrait silhouette (the actual 3D character posed + snapshot via
   the existing camera, or a flat styled card), 1-3 lines of text, tap to
   advance. This is a UI component + a script table — no video.
2. **Venue establishing shots** — 2-3 second `camDirector.snapTo` sweeps of
   the already-built venue before the dialogue (the golf hole-preview
   pattern from M54, generalized).
3. **Beat moments in-mode** — chapter-specific banners/hints already flow
   through the HUD contract (`banner`, `hint`) — rivals "talk" mid-match
   through the same channel the modes already use.

## Progression & rewards
- Chapter clear: Shards + XP through the existing reward pipeline
  (SessionResult.stats — same contract every mode already reports).
- Milestones (Ch 3/6/9/10): cosmetic tint unlocks for the hero (the tint
  system already exists in CharacterLibrary.spawn).
- Chapter select with best-result stars (1-3) for replay.
- Story state = one small JSON blob (chapter index + stars) in the existing
  save/profile storage.

## What this deliberately does NOT include
- No video/mocap cutscenes, no voice acting, no new 3D assets.
- No branching narrative (one season arc, one golden-ending variation).
- No new gameplay systems — chapters REUSE shipped modes via their existing
  ModeDefinition contracts with parameterized win conditions.

## Build shape (when approved)
One batch (~M5x): `story/storyScript.ts` (the chapter/dialogue table),
`story/StoryDirector.ts` (chapter orchestration wrapping existing modes),
`ui/StoryDialogue` spec for the bezel, hub card "THE RUN" → `/play/story`.
Estimated at one focused batch because every heavy system already exists.
