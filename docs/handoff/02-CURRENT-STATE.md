# 02 — CURRENT STATE OF THE LIVE BUILD (verified by hands-on playtest)

**Build:** finalevolution.abacusai.app (nexusllm.abacusai.app serves the identical app)
**Verified:** July 2026, real browser sessions — guest funnel, account creation,
hub/modes navigation, and live play of Dunk Contest (~20 attempts), Karate Endless,
Skate Run, Street Football. Screenshot evidence captured for every claim below.
**Stack (observed):** Next.js-style React web app; 3D gameplay renders in WebGL
(three.js-class). Mobile-viewport aware. Routes seen: `/`, `/try`, `/login`, `/signup`,
`/modes`, `/play/{karate|skateboard|football|…}`.

## A. What is GOOD (protect these)
- **Landing & guest funnel:** "60 SECONDS TO A DUNK … PLAY NOW" → `/try` guest dunk
  with no account. Strong concept, converts curiosity instantly.
- **Onboarding:** arena picker (Streetball/Karate/Skate/Surf/Snowboard/Tennis) with
  attractive venue thumbnails → athlete profile → straight into the hub.
- **Hub/meta layer:** PRQ + Lab Credits top bar; profile card (PRQ 53, 500 LC, XP,
  streak); **Season Pass "Golden Hour"** (Free/Pro lanes, 56-day season, tier
  progress); Signature Challenge (weekly seeded, 1 shot/day, global leaderboard);
  Triumph Arena (LC-stake duels); venues (Luma Venice Shop · Market Browse, Muscle
  Beach Gym · Iron Paradise/Beach Sprint); bottom nav Home/Modes/Coach/Story/Profile.
- **Modes library:** "22 live modes. Every session feeds your PRQ." Confirmed cards:
  Karate Endless (Shimogamo Dojo), Dunk Contest (Venice Beach Court), Match Play +
  Tiebreak Blitz (Venice Tennis Court), Brain Brawl + Who Scene It (NeuroArena),
  Skate Run (Venice Skatepark), Penalty Shootout (Coastal FC Stadium), Home Run Derby
  (Catalina Ballpark), Slalom Descent + Big Air (Mountain Slope), Beach Sprint
  (Muscle Beach Gym), Karate Versus, The Nexus Initiative (Sanctum/rails/Glitch Boss),
  Street Football (The Gridiron), Surf Break, …
- **Result screens:** XP / shards / credits / PRQ Δ tiles + season-XP bar with tier
  markers + CHALLENGE A FRIEND / REPLAY / HUB. Polished; the loop closer works.
- **Environment art (varies):** Shimogamo Dojo is genuinely atmospheric; venue
  thumbnails are strong. Golden-hour sky + pink rim on the dunk court are good.
- **DDA exists:** karate HUD leaked "AGGR 0.68 · SPD ×1.01" — adaptive difficulty is
  wired (should be hidden from players, but the system is there).

## B. What is BROKEN (the M13 batch, `docs/abacus-batches/m13/`)
Five systemic root causes, each verified in play:
1. **Animations don't fire on input** — karate strikes, skate tricks, football jukes,
   dunk styles: state changes, mesh doesn't. (m13-01)
2. **Characters face the wrong way** — dunk (chest to sideline at rim), karate
   (fighters face away from each other), football (runner back-pedals downfield). (m13-01)
3. **No uniform controller** — gamepad FAB exists in Karate/Skate only; guest dunk
   shows "WASD" hints on phones; football starts before controls are readable. (m13-02
   — now superseded/expanded by `03-CONSOLE-SHELL-SPEC.md`)
4. **Camera loses the action** — dunk RISE films the floor (player/ball out of
   frame); karate camera sits behind a dojo pillar; board-sport cam drops so low the
   unlit ground reads as a black void (see-through at angles). (m13-03, m13-05)
5. **Placeholder capsules** — dunk rival and all six football defenders are static
   pink pills; no skinned opponents anywhere in those modes. (m13-04, m13-06)

Mode-specific detail (ball detached/invisible in dunk flight, "WAVE 1 CLEAR · 0 KO"
without kills, tackled at 17 yd in ~2 s, black skatepark, flooded-looking dunk court,
score "0.0" formatting, style cards occluding the slam) is fully written up in the
nine m13 docs with acceptance criteria. **M13 remains the active fix milestone.**

## C. What does NOT exist yet (gap to the 01 vision)
- **The console shell**: home is a (good) web dashboard, not yet a console home; no
  cartridge/boot/exit transitions; no persistent console frame around gameplay.
- **The universal controller**: nothing close to the dual-stick/dual-trigger/d-pad +
  touch overlay of `03-CONSOLE-SHELL-SPEC.md`; Gamepad API unsupported.
- **Coach tab depth**: tab exists; coaching/fitness programming (plans, PRQ-driven
  recommendations, gym cartridges as first-class modes) not yet built out.
- **Uniform ready gates / countdowns** across modes.
- **Physical gamepad + haptics** support.

## D. Known environment/infrastructure notes for agents
- Two domains serve one build; custom domain planned — keep base-URL relative.
- Guest `/try` is the acquisition front door: any shell/controller work MUST include it.
- The live app's source is not in this repo; changes ship as document batches the
  Abacus builder applies (protocol: `07-AGENT-PIPELINE.md`).
