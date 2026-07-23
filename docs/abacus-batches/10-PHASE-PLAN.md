# FEL — 10-Phase Execution Plan

Everything currently on the backlog, organized into 10 phases. Each phase
ships as one or more numbered drag-and-drop batches (`mNN-...`) in
`docs/abacus-batches/`, following the same self-contained format as every
batch so far (README + `files/`). Phases are ordered so each one builds on
verified ground rather than stacking new gameplay on an unconfirmed fix.

Named games/apps throughout (NBA Live, 2K, THPS2, Naruto Ultimate Ninja
Storm, Soul Calibur, NFL/FIFA Street, Wii Tennis, BandLab) are used strictly
as **informal mechanic references** — genre-standard feel and control
conventions to build toward — never as a source of copied assets, code,
character names, or branding. This is the same rule already enforced for
Who Scene It and the Karate "Agent Waves" rebuild.

Three things are explicitly OUT, per the boundaries already set with you:
the personal tax-shelter/wrapper document (declined — CPA/attorney matter,
not code), real networked multiplayer transport (no infra visibility — the
input abstraction is built, a transport isn't), and real third-party
credentials for Spotify/Apple Music/Amazon KDP (FEL-side UI + integration
seams only, until you have real developer accounts to wire up).

---

## Phase 1 — Animation root-cause investigation ✅ shipped (M51)
Re-audited Dunk Contest live per your note that "something is still not
working." Found the character sits in a dead bind pose through the whole
charge/launch sequence despite every layer I can inspect (clip resolution,
registration, crossfade weight) proving correct via live bundle
instrumentation. Shipped `SkinningGuard` (self-detects + auto-mitigates a
stalled skinning pipeline, loud console line) and a confirmed-live fix to
`CharacterAnimator` (every mode's per-frame `.play(sameClip)` call was
resetting animation weight every frame). **Needs your real-device check** —
full findings in `m51-skinning-stall-guard/00-README-PROMPT.md`.

## Phase 2 — Basketball ecosystem polish
- Dunk Contest: THPS2-style score-chaining feel + NBA-Live-style broadcast
  polish (camera cuts on makes, Venice court dressing pass, prop variety).
- 1v1 Hoops / 3v3 Streetball: 2K-Blacktop-referenced physics — collision
  resolution, ankle-breaker crossovers, shot variety (fadeaway/floater/post),
  tuned contest math.
- **Wiring gap fix**: `modeVerbs.ts` never got explicit entries for
  `onevone`/`threevthree`/`carnival` (M48/M49) — live evidence shows a
  generic "ACTION" button instead of contextual prompts. Small, concrete fix.
- Confirm M48/M49/M50 are actually live (only M47 was confirmed this cycle).

## Phase 3 — Combat modes
- Karate Endless: verify Agent Waves (M50) landed correctly; tune wave pacing.
- Karate 1v1: Naruto-Storm-referenced — hit-stun chains, guard-break rhythm,
  clash/parry read-and-react windows.
- **New mode**: Mixed Combat 1v1 — Soul-Calibur-referenced 8-directional
  spacing, ring-out edges, weapon-vs-unarmed matchup variety. Built on the
  same `PlayerSlot`/`ControlSource` co-op-ready foundation as M48/M50.

## Phase 4 — Field & court sports
- Football: NFL-Street-referenced traversal (juke/spin/truck stick feel,
  already-partial from M45, deepen the animation variety).
- Soccer: FIFA-Street-referenced first-touch + skill-move input buffer.
- Tennis: Wii-Tennis-referenced joystick swing (timing + direction on the
  stick rather than a flat button), rally pacing.
- Golf: over-the-shoulder camera cut to the hole pre-shot, timed tap/swipe
  power+accuracy swing meter.

## Phase 5 — Board & action sports
- Surf: funnel/tunnel wave geometry + obstacle set (matches the M44 lap-wrap
  fix with actual varied wave shape, not a flat repeating lap).
- Snowboarding: trees/obstacles, rails, a ski-lift grind gimmick, and — your
  ask — a **Yeti mob** (original creature design, no franchise likeness).
- Skateboarding: map expansion (bowls, downhill straights, more rail variety)
  on top of the existing trick machine.
- Gymnastics: audit pass (current state unclear — assess before building).

## Phase 6 — Party hub & assessment-needed modes
- Court Carnival: add more event variety beyond the 4 shipped in M49.
- Art mode: audit + improvement pass.
- Who Scene It / Brain Brawl: audit pass (both already under the
  original-content-only rule).
- Head-to-Head IRL Dunk Contest: build out (distinct from the AI-judged solo
  Dunk Contest — a live 1v1 format).
- Story Mode: gameplay/cutscene/interaction design — this is the least
  currently defined of everything on the list, so it starts as a design pass
  (what's the actual loop?) before any code.

## Phase 7 — Music: creation studio (FEL-side, buildable now)
Your BandLab-as-template ask, researched and folded in. BandLab's actual
strengths worth mirroring in FEL's own UI (not their code/branding): an
in-browser multi-track mixer, a loop/instrument library gated by unlocks,
one-tap "master this" polish, and creator-to-creator remix/collab on a
shared project. All buildable FEL-side against Cell/Nexus (Shards-gated
generation) with zero external dependency.
For the presentation layer — the "Andre 3000 cartoon-network type video
game" reference — that's **Class of 3000**'s tone: a vibrant, stylized
music-school setting with a mentor-character cast. FEL can build an
**original** campus/mentor cast in that spirit (distinct character designs,
no likeness or IP from the show) as the Studio hub's visual identity, with
Cell/Nexus AI-assisted composition (gated by Shards per your existing
economy) as the actual creation engine. Includes: save/library (every track
a creator makes, browsable, playable), and per-creator song lists other
players can see and save to their own library.

## Phase 8 — Music: display + external streaming (honest integration seam)
Three things you asked for specifically: (1) display and control Apple
Music/Spotify-hosted tracks inside FEL, (2) real creation/publishing studio
storage (this is Phase 7), (3) external-streaming-authorized playback on
save. All three need REAL Spotify/Apple Music developer credentials I don't
have — this phase builds the FEL-side half honestly: a "Connect your
streaming account" UI, a playback-control surface wired to a clearly marked
integration seam, and the local save/library plumbing — so the moment you
have real API keys, wiring the last mile is a config change, not a rewrite.
Also answers your NVIDIA "motion bricks" question directly: that's not a
real, current NVIDIA product/API — nothing to integrate there.

## Phase 9 — Creator economy & marketplace
- $30 all-access subscription pass — fully buildable, straightforward gate.
- Book/audiobook/art marketplace: FEL-side storefront, Creator Cards,
  Shards-priced listings, Cell/Nexus-assisted authoring tools (with your
  20-chapter/bestseller-structure prompts as an authoring template). Amazon
  KDP distribution is flagged as its own seam — needs your real KDP account
  to go live, same pattern as Phase 8's streaming seam.
- Food-scan AI nutrition scoring for coins/XP/Shards rewards, judged against
  the player's own stated goals/data (not a generic score).

## Phase 10 — Ghost-kitchen marketplace + full regression pass
- Ghost-kitchen subscription marketplace (the legitimate, reframed version
  of your food-business idea — a plug-in-play rental/subscription system
  for kitchens, independent of the tax-shelter framing I declined earlier).
- Closing phase: run the full KNOWN-ERRORS regression sweep across every
  mode shipped across all 10 phases, confirm nothing from Phase 1–9 regressed
  anything else, and do a final comprehensive live playtest audit of the
  whole app end to end.

---

**Status:** Phase 1 is packaged now (`m51-skinning-stall-guard/`). Phases 2–10
will each ship the same way — README + files, ready to drag into Abacus —
one phase (or logical sub-batch within a phase) at a time going forward.
