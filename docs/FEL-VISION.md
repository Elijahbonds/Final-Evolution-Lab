# Final Evolution Lab
### Vision, Analysis & Synopsis

**Prepared for:** Elijah Bonds, Founder
**Canonical product:** finalevolution.abacusai.app (nexusllm.abacusai.app serves the identical build)
**Status:** Living document — supersedes prior scope where noted; reconciled against `docs/handoff/01-PRODUCT-VISION.md` and `docs/handoff/02-CURRENT-STATE.md`
**Date:** July 2026

---

## Abstract

Final Evolution Lab (FEL) is a browser-native athlete platform that fuses three
categories usually built as separate products — a home-console game library, a
digital fitness coach, and a skill-based competitive arena — into a single
persistent identity: the player's own athletic performance, expressed as one
number (PRQ, Performance Readiness Quotient) that travels with them through
every mode. The product's defining constraint is also its differentiator: it
must *feel* like inserting a cartridge into a console, not like opening a web
app, while running entirely in a browser with no install. FEL currently ships
22 live game modes across ten sport families (basketball, karate, football,
skateboarding, snowboarding, surfing, tennis, golf, baseball, soccer) plus a
meta layer (Season Pass, Signature Challenge, Triumph Arena, NeuroArena) and
is in active build-out of a real-money skill-competition arena (Cash Dunk
Arena) and a computer-vision-driven coaching layer (body/face scan character
creation, IRL performance judging). The build is produced through a distinct
multi-agent development pipeline — the founder directs and playtests, an
autonomous Abacus-hosted builder owns and ships the live app, and this repo's
role is playtest, diagnosis, and code-complete "batch" authorship — because
the founder does not write code directly. This document lays out where the
product is going, what stands in the way, and how the pieces already built
close that gap.

---

## Synopsis

Most fitness apps ask for discipline and give back a chart. Most sports games
ask for a purchase and give back an afternoon. FEL's bet is that neither has
to be true in isolation — that a real athletic identity, expressed through
arcade-tight game modes and backed by a legitimate skill-based competitive
economy, is a stronger loop than either alone. The player lands on a console
home screen, not a dashboard: a library rail of game "cartridges," a
persistent avatar, a currency bar, a season pass ticking in the background.
Picking a cartridge boots a mode — Dunk Contest, Karate Endless, Street
Football, Skate Run, Slalom Descent, Surf Break, Match Play, Links Challenge,
Home Run Derby, Penalty Shootout — each a tight, 60-second-to-fun arcade
experience that reports results back into one economy (XP, shards, Lab
Credits, PRQ). A guest can dunk in under a minute with no account. A returning
player has a Season Pass, a weekly Signature Challenge, a Triumph Arena to
stake Lab Credits on head-to-head duels, and — in the arena now under active
build-out — a path to compete for real prize pools against the recorded
"ghost" of another real competitor, scored by deterministic AI judging that
can be replayed and audited, not gambled.

The honest state of the build, verified through hands-on playtesting rather
than assumed: the hub, onboarding, meta layer, and result screens are strong
and should be protected as-is. The game modes underneath them were, as of the
most recent full sweep, in varying states of repair — some (basketball,
karate, football) had working economy logic wrapped around broken or
invisible gameplay; three (the board sports) rendered no world at all; four
(the precision sports) never spawned an athlete or the furniture their sport
requires. None of this reflects a flawed concept — it reflects a build in
motion, being fixed family by family, with each fix batch built on a
foundation (grounded animation, one unified control scheme, camera framing
that actually follows the action, and a runtime guard system that turns
regressions into loud errors instead of silent decay) engineered specifically
so that once a defect is closed, it stays closed. That foundation, and the
game-by-game rebuild on top of it, is most of what this document's Analysis
section covers in depth.

---

## Vision

### The one sentence

**Final Evolution is a digital coaching and fitness platform wrapped in a
personal game console: your athlete avatar carries real training identity
into a library of sports game modes that look like a console and play like a
handheld.**

### Why a console, and not a website

The console framing is not a skin. It is the product's central promise about
*how it will feel to use*, and every technical decision downstream — the
unified controller, the boot/cartridge transitions, the persistent avatar
rail — exists to make that promise true. A stranger looking at the home
screen should say "that's a game console," not "that's a fitness app with
sports minigames." That distinction matters because the category FEL is
actually competing in is attention, not workouts logged: it is competing
against console gaming for the couch hour, and it wins that competition by
being the one console you don't have to buy, plug in, or update — it's
already open in a tab. The controller reinforces this: a persistent
dual-stick, dual-trigger, d-pad-plus-face-button overlay that behaves
identically in every mode, layered with direct touch for taps and swipes —
the same hybrid a Switch or Steam Deck offers, arrived at independently
because it is the correct answer for "console feel, browser deployment, phone
first."

### Why the athlete identity is the spine, not a feature

PRQ (Performance Readiness Quotient) is the one number every mode writes to
and every coaching surface reads from. It is what makes FEL a *platform*
rather than a bundle of ten unrelated arcade games: a great Karate Endless run
and a strong week of logged training both move the same needle, and the Coach
tab's recommendations, the avatar's presence, and the player's standing in
Signature Challenge all key off it. This is the mechanism by which "fitness
app" and "game console" stop being two products glued together and become one
loop — play feeds identity, identity feeds coaching, coaching feeds play. The
long-term ambition is for real-world training signal (logged workouts, and
eventually motion-captured IRL sessions scored by the same computer-vision
pipeline that powers the Cash Dunk Arena's IRL Proving Ground) to raise PRQ
directly, so the game library becomes the *reward loop* that makes training
sticky, rather than training being a chore that unlocks games.

### Why skill, never chance

The Cash Dunk Arena — competing for real money against the recorded
performance of another real competitor, scored by AI judges on deterministic
athletic metrics — is the highest-risk, highest-differentiation piece of the
platform, and its design center is a single non-negotiable: **every outcome
must be a pure, replayable function of measured performance.** The same
recorded run, replayed, produces the same score, every time, on the server,
independent of the client. This is what allows FEL to build a legitimate
skill-competition product instead of a gambling product wearing a sports
skin — and it is why the architecture (documented in full in the Analysis
section) treats the scoring function itself as the single most protected
piece of code in the platform, shared byte-for-byte between the client that
plays the game and the server that verifies it.

### Where this goes

The near-term vision is completing the console-emulator fantasy end to end —
boot transitions, a true console home, physical-gamepad support via the
Gamepad API — layered on top of a game library where every mode is actually
good, not just economically wired. The mid-term vision is the Coach tab
becoming a real training platform: PRQ-driven daily plans, gym-cartridge
mini-modes, group and private coaching sessions, and a "Cell" AI coach that
knows the player's whole training and play history. The long-term vision is
the Cash Dunk Arena's model — deterministic skill scoring, ghost-based
head-to-head, IRL judging via phone camera — extending across the mode
library, so that any sport in FEL's library can eventually host a legitimate
competitive economy, not just basketball.

---

## Analysis

### 1. Product analysis — the three pillars, and where each one stands

**Pillar 1 — The Console (shell).** The app is meant to *be* the hardware:
console home, cartridge library rail, boot/exit transitions that sell the
fantasy. Today this pillar is the least built of the three — the home screen
is a good web dashboard, not yet a console home, and the universal controller
described in the shell spec does not yet exist in the live build. This is
tracked, scoped, and sequenced work, not an open question; it is next after
the mode library itself is sound, because a console home wrapped around
broken cartridges would only foreground the defects.

**Pillar 2 — The Athlete (coaching & fitness identity).** PRQ, the persistent
avatar, and the Coach tab shell are live; the deeper coaching layer (training
plans, PRQ-driven recommendations, gym cartridges as first-class modes) is
not yet built out. This session's batch work extends this pillar directly:
MediaPipe-driven body-scan and face-scan character creation (so the avatar is
actually *you*, not a generic model), an exercise-demo system pairing avatar
playback with real video, and scheduled group/private coaching sessions.

**Pillar 3 — The Library (game modes).** This is where the most recent and
most extensive work concentrated, because it is where the gap between vision
and live build was largest. A full ten-mode playtest sweep (basketball,
karate, football, skateboarding, snowboarding, surfing, tennis, golf,
baseball, soccer) found every mode loading and running, but in three distinct
states of repair:

| State | Modes | What was actually observed |
|---|---|---|
| **Logic works, gameplay doesn't render correctly** | Dunk Contest, Karate Endless, Street Football | Scores advance, downs tick, rewards pay out — but the camera never frames the player, characters sink into the floor or hold a T-pose, and two incompatible control schemes render on screen at once, so neither works. |
| **Nothing renders** | Skate Run, Slalom Descent, Surf Break | Timer and score chip work; the 3D viewport is a flat, empty color. No park, no slope, no wave — no world was ever built for these three modes. |
| **No athlete, no furniture** | Match Play, Links Challenge, Home Run Derby, Penalty Shootout | A ball sometimes moves and rounds advance, but no character ever spawns to swing, aim, or kick, and the net, flag, plate, and goal that make each sport legible are absent. |

Each state has since been diagnosed to a root cause and closed with a
dedicated fix batch (detailed in the Technical Architecture analysis below):
a unified touch/keyboard/gamepad control layer and an animation-grounding fix
for state one; fully-built procedural worlds and a shared trick engine for
state two; a shared athlete-and-furniture engine for state three. The meta
layer surrounding all ten modes — hub, Season Pass ("Golden Hour"), Signature
Challenge, Triumph Arena, NeuroArena (Brain Brawl, Who Scene It), and the
result-screen economy — was independently verified as strong and is treated
as protected surface area: fix batches are written not to touch it.

### 2. Market & competitive analysis

FEL sits deliberately between three categories that rarely overlap:

- **Arcade sports games** (mobile and console) compete on production value and
  session length but carry no persistent athletic identity and no connection
  to the player's real training.
- **Fitness and coaching apps** (wearable-driven trackers, video coaching
  platforms) build real identity and habit loops but are visually and
  emotionally flat compared to a game — logging a workout has none of the
  texture of playing one.
- **Skill-based real-money competition platforms** exist, but the credible
  ones are narrow (single-game, often card or trivia based) and the sports
  ones frequently blur the skill/chance line in ways that invite regulatory
  scrutiny.

FEL's wedge is refusing to pick one. A console-grade game library gives it
the emotional pull fitness apps lack; a persistent PRQ identity gives it the
retention hook arcade games lack; a deterministic, replayable scoring model
gives it a legitimate path into real-money competition that pure arcade
platforms can't credibly claim. No single competitor is positioned to copy
all three at once without rebuilding from the ground up, which is the
platform's actual moat — not any one game mode.

The guest funnel is the sharpest existing proof of this positioning: "60
seconds to a dunk" with no account required converts curiosity into a played
session immediately, which is a stronger top-of-funnel than either a fitness
app's signup wall or a premium game's download size.

### 3. Technical architecture analysis

The live build runs a browser-native 3D engine (Babylon.js, migrated during
this project from an earlier three.js implementation) with Havok physics, and
the technical work this session concentrated on four load-bearing layers that
every game mode depends on:

**Character reliability.** Two silent, game-wide defects were found and
closed at the root: imported character animations were losing their name
identity during instancing (breaking every animation lookup across every
mode simultaneously), and imported clips carried position data in a
coordinate space that put characters underground once their animation
finished, dropping them into a T-pose. Both are now fixed with a systematic
sanitizer applied once, centrally, to every spawned character, plus a
per-frame "ground lock" that makes sinking physically impossible regardless
of what any individual animation clip does.

**One control system.** The most visible symptom in the live audit — "two
different button sets that don't work" — traced to exactly that: legacy and
new control overlays mounted simultaneously, neither wired to the game's
actual input bus. The fix establishes one touch control deck, one keyboard
map, and one gamepad path, all emitting the same input events, with an
explicit rule enforced batch-over-batch: exactly one control system may exist
at a time, and every batch that touches input includes deleting whatever it
replaces.

**Camera framing.** The single defect with the widest blast radius across
every mode was a camera system that aimed at the ground rather than the
subject, with no limit on how far it could pitch downward — the practical
effect was players staring at fighters' feet, an empty basketball lane, or a
football field with no visible runner while the game logic played itself
unseen. The camera director was rebuilt to target chest height, clamp its
pitch into a legible range, and snap to a correct frame the instant a mode
loads, rather than drifting into one over time.

**Regression discipline.** Because this build has visibly regressed before —
a fix landing in one area breaking something that previously worked — the
project now maintains a numbered ledger of every defect ever encountered
(currently fifteen, `docs/abacus-batches/KNOWN-ERRORS.md`), each with its
root cause, the batch that fixed it, and a concrete, automatable check that
proves it hasn't returned. Two of those checks are runtime guards shipped
into the live app itself: one that asserts a mode's world actually contains
geometry before it's allowed to reach "playing" state, and one that watches
the player's on-screen position continuously and raises a loud, specific
error the moment they leave frame — turning what used to be a silent visual
regression into an immediate, diagnosable signal.

**The cash-arena scoring model.** The Cash Dunk Arena's determinism guarantee
is implemented, not just promised: a single simulation function, seeded and
free of any wall-clock or random dependency, consumes a compact recording of
the player's raw inputs and produces the run's score. The client runs this
function to score the player immediately; the server re-runs the identical
function against the same input recording to verify before any prize money
moves. Money rails (Stripe Checkout for entry, Stripe Connect for payout,
Stripe Identity for age verification) are architecturally separate from the
shards/Lab-Credits economy that powers the rest of the game, by design — cash
never touches the in-game currency ledger.

### 4. Business model & monetization analysis

FEL's monetization is layered by risk and by how directly it touches money:

- **Season Pass** (free and paid lanes, cosmetic-only on the paid lane per
  standing product policy) is the lowest-risk, highest-volume layer —
  ordinary engagement monetization with no wagering characteristics.
- **Triumph Arena** stakes Lab Credits — an internal, non-cash currency — on
  head-to-head duels. This sits inside the existing game economy and carries
  none of the compliance weight of real money.
- **Cash Dunk Arena** is the real-money layer, and is treated with
  commensurate care: a declared platform rake, a defined payout split across
  top finishers, a mandatory post-contest review window before funds release,
  and a compliance gate in front of every cash action — region check, age
  verification, and weekly entry/deposit limits — that free contests never
  pass through and never need to. Self-exclusion is a first-class, player-
  facing control, not a support-ticket afterthought.
- **IRL Proving Ground** extends the same scoring model to real, filmed
  athletic performance, analyzed on-device (the video itself never leaves
  the player's phone) — a bridge between the coaching/fitness pillar and the
  competitive-economy pillar that is unique to this platform's shape.

The throughline across all four layers is the same design center as the
technical architecture: skill is scored deterministically and can be
audited, which is the difference between a defensible skill-competition
product and a liability.

### 5. Development methodology analysis

FEL is built through a four-role pipeline that exists because of one hard
constraint: the founder directs the product but does not write code. Elijah
sets direction and is the final judge of every build, playtesting each
deployed version personally. An Abacus-hosted autonomous builder owns and
hosts the live application and is the only party that actually ships changes
to production. This repository's role — the work reflected throughout this
document — is to close the gap between those two: playtesting the live build
firsthand with a real, automated browser session (not assumption), diagnosing
root causes rather than surface symptoms, and authoring complete, self-
contained "batches" — a README with exact wiring instructions plus every
file needed — sized for a non-technical founder to drag directly into the
builder.

This pipeline's strength is also its risk, and both are worth stating
plainly. Its strength: every fix is verified against a real, deployed build
rather than reasoned about in the abstract, and the founder never has to read
or write a line of code to direct highly technical work. Its risk: the
pipeline has a single production choke point (the Abacus builder), and every
batch depends on prior batches having actually been applied correctly, which
is precisely why the KNOWN-ERRORS regression ledger exists — it is the
mechanism that keeps a multi-batch, multi-week build-out from quietly
undoing its own progress.

### 6. Risk analysis

| Risk | Exposure | Mitigation in place |
|---|---|---|
| **Regression** — a new batch breaks something a previous batch fixed | High, given build history | KNOWN-ERRORS ledger with a mandatory pre-promote sweep; runtime guards (`FrameGuard`, `SpawnGuard`) that fail loudly in production instead of silently |
| **Single-builder dependency** — all shipping runs through one autonomous builder | Structural | Batches are self-contained and idempotent by design; each includes explicit acceptance criteria so a bad apply is quickly detectable |
| **Real-money compliance** — cash contests are a regulated surface | High if mishandled | Deterministic, replayable scoring; geo/age/limit gates on every cash action; USD rails fully separate from game currency; conservative default region list expandable only with counsel sign-off |
| **IP exposure** — NeuroArena's Who Scene It mode | Contained | Standing product rule: no real movie clips, posters, or celebrity likeness; original content only, enforced as a hard constraint on every relevant batch |
| **Scope breadth** — 22 modes plus a console shell plus coaching plus a cash arena | Real | Sequenced, family-by-family rollout (this session: basketball → board sports → precision sports → football) rather than simultaneous work across the whole library |

### 7. Current trajectory

The most recent completed work closes the ten-sport-mode gap identified
above: a shared framing/input/regression-guard foundation, followed by
dedicated rebuild batches for basketball, the three board sports, the four
precision sports, and football — each shipped as a self-contained,
drag-and-drop package with its own acceptance criteria. In parallel, the Cash
Dunk Arena has moved from a rules-and-judging specification to a
code-complete system: deterministic simulation, Stripe money rails, contest
storage and scheduling, ghost recording and playback, and the player-facing
screens (results/leaderboard, responsible-play controls, IRL upload). What
remains ahead, in the sequence this document's Vision section lays out: the
console shell and universal controller, deeper Coach-tab training
programming, and — once the mode library is fully sound — extending the
deterministic competitive model beyond basketball to the rest of the sport
library.

---

## Closing

The console-emulator feeling FEL is chasing is not a visual style — it's a
claim about how effortless and how *alive* the product should feel the
instant it opens, on any device, with no install and no friction. Everything
documented here, from the animation-grounding fix to the cash-arena
determinism guarantee, exists in service of that one claim being true in
every mode, every time, for every player. The gap between where the build is
and where the vision points is real and specifically mapped — not vague — and
it is closing family by family, batch by batch, with a regression ledger
making sure it closes in one direction only.
