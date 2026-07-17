# M13-07 · P2 — Karate Endless + Karate Versus (Shimogamo Dojo)

## Observed (live playtest — Karate Endless)

1. **Fighters face the wrong way.** Player and enemies stand facing away from each
   other / away from camera; nobody squares up. (Root fix in doc 01 §B — engagement
   facing: always face current target.)
2. **Attack inputs fire no animations.** J / Space / E during an active wave produced
   zero pose change on the player across 700 ms screenshot intervals (doc 01 §A).
3. **Wave logic runs itself:** "WAVE 1 CLEAR · 0 KO" banner appeared with the wave
   counter already at WAVE 2 (enemies remaining: 5) while the player had landed nothing.
   Waves must not clear without kills — audit the wave-complete condition (it appears to
   fire on timer or on enemies despawning, not on KOs).
4. **Camera behind the dojo pillar:** the central structural pillar occludes the middle
   of the mat; the fight happens far away at the frame edge (doc 03 fix + occlusion
   fade).
5. **Raw DDA telemetry on the HUD:** "AGGR 0.68 · SPD ×1.01" is developer data; players
   shouldn't see tuning scalars.
6. No player/enemy health bars, no chakra/special meter visible in the fight frame.
7. **The dojo environment is genuinely good** (lanterns, cherry blossoms, warm light)
   — keep it; it's the best-looking arena in the build.

## Required fix

1. **Engagement system:** nearest live enemy = current target; both player and target
   face each other (doc 01 §B). Target switch on KO or on stick direction + attack.
2. **Full strike kit wired to clips** (doc 01 clip map): jab/cross/kick/block/chi
   special, hit-reacts on enemies, KO fall, and a wave-clear player pose.
3. **Wave integrity:** a wave clears ONLY when its enemy count reaches 0 via KOs.
   Kill counter and "WAVE N CLEAR · X KO" must agree with what happened.
   Add a 2–3 s WAVE CLEAR beat (banner + pose) before the next spawn.
4. **HUD:** player HP, enemy HP pips over active target, chi/special meter. Remove
   AGGR/SPD readout (keep behind a dev flag).
5. **Camera:** raised 3/4 framing, occlusion probe vs. the pillar (doc 03), both
   fighters ≥25% frame height.
6. **Controller overlay** config (doc 02): stick move · A strike · B kick · X block ·
   Y chi special.
7. **Versus mode:** same fixes apply; verify round structure (best of 3 vs Rival
   Sensei) has KO freeze-frame (0.3 s) + round banner before reset.

## Acceptance
- Recording: player squares up to each enemy, every input plays its clip, enemies
  hit-react and fall on KO, wave banner count matches actual KOs.
- No wave advances without the on-screen KO count reaching the wave's enemy count.
- Pillar never hides the fight; DDA numbers gone from player HUD.
