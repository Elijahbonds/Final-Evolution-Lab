# M22 — MAKE ANIMATION REAL · WORLDS ALIVE · SCAN REPURPOSE

Copy everything below into Abacus.

---

## PROMPT FOR ABACUS

Execute this pass in the order given. **The animation system has now failed three
passes in a row — this pass changes strategy instead of retrying the same fix.**
Section 1 is the gate: if characters still T-pose or slide after it, stop and
report the diagnostic output. Every section ends with a recording proof. Do not
regress: dojo background (Section 2), meta layer, wallet flows, FEL LIVE, sessions.

---

## 1. ANIMATION — CHANGE OF STRATEGY (the gate)

### 1.1 Stop retargeting. Use models with animations baked in the same file.
Prior passes failed because clips and skeletons were married at runtime (retarget/
bone-name mismatch → bind pose). Eliminate the failure class:

- **Adopt a character asset set where mesh + skeleton + ALL animation clips live in
  ONE GLB file.** Same-file AnimationGroups bind by construction — there is nothing
  to retarget at runtime. Source: export characters through Mixamo (or equivalent)
  with each needed clip baked, merge clips into one GLB per character in Blender
  (one armature, many actions → glTF animations). If licensing/time blocks that,
  use a CC0 rigged+animated pack (e.g., Quaternius/KayKit humanoids) as the interim
  gameplay body — a stylized model that ANIMATES beats a realistic model that
  T-poses. Recreate/replace the current hero asset if that is what it takes.
- One canonical skeleton for the whole game (Section 3.2) — every mode pulls
  characters from a shared `CharacterLibrary`, no per-mode rigs.
- Keep the M15 CharacterAnimator (cross-fade weights old→0/new→1). With same-file
  clips, `targetedAnimations.length === 0` becomes impossible for shipped assets;
  keep the error path anyway.

### 1.2 Animation state = a movie in the scene (confirm + finish)
The CinematicMoveEvent approach stands: significant actions play authored full-body
sequences in-scene with authored cameras (a "movie in the scene"). This pass makes
it REAL in the hero mode:

- **The Eastbay standard (dunk contest reference dunk):** the SIG dunk must read
  frame-by-frame — sprint → two-foot gather → rise with ball in both hands →
  **ball pushed down UNDER the raised knee, passed hand to hand between the legs
  (eastbay/between-the-legs)** → off-hand carries it up → one-hand extension →
  **flush through the rim** → rim hang beat → drop and land in a crouch. The ball
  is parented hand→hand→hand through the sequence — it must NEVER float or teleport.
  If this one dunk looks right, the pipeline is proven; POWER (two-hand tomahawk)
  and FLASHY (windmill) follow the same build.
- **DUNK REPLAY CAMERA:** after every made dunk, auto-play a replay — record the
  last ~4 s of bone transforms + ball path, then play back at 0.5× from TWO angles
  (low baseline angle, then rim-side profile), with a "REPLAY" tag, skippable on
  tap. Feed the best frame to the poster capture (M16 B1). This is a recorded-
  transform replay, not a video capture — cheap and deterministic.

**Section 1 proof:** continuous recording — a full eastbay dunk with trackable ball
(no cuts), the auto replay from both angles, then a karate strike and a run cycle
on the same character library. Zero T-pose frames, zero foot-sliding.

---

## 2. KARATE — REGRESSION + MOB VARIETY

1. **REGRESSION: the Shimogamo Dojo background is GONE.** It previously rendered
   (lanterns, cherry blossoms — best scene in the build) and now the mode plays on
   a void. Restore the dojo environment and add it to the regression checklist so
   no future pass can ship without it.
2. **Random mobs with model variety:** enemy waves must draw from a randomized pool
   — the shared CharacterLibrary (Section 3.2) provides multiple enemy models;
   randomize per spawn: model, gi/outfit palette, scale (0.92–1.08), and archetype
   (striker/grappler/rusher affects behavior). No two waves identical.
3. Enemy rigs come from the same baked-clip GLBs — mob strikes/hit-reacts/KO falls
   must animate under Section 1's system.

**Proof:** three consecutive waves showing visibly different enemy mixes, all
animating, dojo fully present at every camera angle.

---

## 3. SHARED CHARACTER LIBRARY (rig once, use everywhere)

1. **`CharacterLibrary`:** every humanoid in the game — player avatar, karate mobs,
   football defenders, 3v3 teammates/opponents, dunk rival, seminar/gym avatars —
   loads from one library of baked-clip GLBs on ONE canonical skeleton.
2. All modes consume the library; the Closet look (M20 `resolveLook`) and scan
   proportions (M17) apply as material/palette + bone-scale layers ON TOP of
   library models. Rig the existing alternate models so they are usable in ALL
   modes — no mode-locked characters.
3. Kill remaining capsules/placeholders anywhere they still render.

**Proof:** the same library character appearing (with different outfits) in karate,
football, and 3v3, animating in each.

---

## 4. SYSTEM SCAN — REPURPOSE (it is NOT a game mode)

The System Scan currently plays like another basketball mini-game. That is wrong.
**The System Scan is a diagnostic tool and avatar-creation source:**

1. Remove the basketball-game framing from the scan flow entirely.
2. Scan flow = M17: consent → film movement screen/stress test → client-side pose
   extraction → diagnostic report (metrics, deficits, PRQ axis updates) → **avatar
   proportions**.
3. Scan output + **Closet data (M20)** together build the player's visual
   appearance: scan gives body proportions; Closet gives face/hair/wearables. The
   post-scan flow routes THROUGH the Closet ("fix your look") before the reveal.
4. The scan surface in the app presents as a LAB/diagnostic screen (readout panels,
   metric axes, deficits, retest history) — clinical, not arcade. Vertical-jump
   results still log to `vertical_jump_log`; game modes remain the place where PRQ
   is expressed, not measured.

**Proof:** scan flow recording showing diagnostic report + avatar update, with no
basketball gameplay anywhere in it.

---

## 5. BOARD SPORTS — CONTENT, COINS, MOBS, THE LIFT & THE YETI

### 5.1 All board modes (skate · surf · snowboard)
- **More to interact with:** minimum per park/run — 6 rails/grind lines, 4 ramps/
  kickers, 2 half/quarter pipes, ledges, gaps, and a marked line that chains them.
- **Collectible COINS on the course:** coin pickups along lines and in air arcs
  (reward risk lines) — collected coins pay into the real coin wallet at session
  end via the standard result flow (server-validated cap per run, e.g. 60).
- **Mobs + obstacles:** course-appropriate moving hazards (pedestrians with
  strollers on the boardwalk, seagulls, cones, ice patches) — hit one = bail
  (fail-forward: lose combo, keep run).

### 5.2 Snowboard signature content
- **Overhead ski lift you can SEE and GRIND:** lift pylons + moving chairs cross
  the slope overhead as living background; the CABLE is grindable — catch enough
  air off a big kicker to reach it, land a cable grind for a large trick bonus
  (balance meter, dismount into the slope).
- **THE YETI:** a yeti mob on the slope. Hit it and it knocks you off the board
  (dedicated knockdown movie event). After first contact it TRACKS you — pursues
  down-slope for a stretch (steering pursuit, growl audio cue, screen-edge
  indicator); outrun it with speed/air or it knocks you down again. It gives up
  after ~12 s or a big jump. Yeti is a library character (Section 3) with baked
  run/swipe/roar clips.

**Proof:** one snowboard run showing coin line collection, a lift-cable grind, and
the yeti hit → chase → escape sequence.

---

## 6. BACKGROUNDS & VISUALS — ALIVE, EVERY SIDE

1. **Views for every single side:** venue boxes upgrade from 4 flat walls to full
   360° dressing — all four sides + skybox + distance layer must hold up because
   cameras orbit. No angle may show void, seam, or unlit black (regression rule).
2. **Alive layer per venue** (ambient motion, cheap): Venice — ocean shimmer, palms
   swaying, boardwalk walkers, the Hoopbus with idle crowd; Dojo — candle flicker,
   falling petals; Gridiron — floodlight moths, flag wave; Slope — snowfall, the
   ski lift (5.2), distant skiers; Skatepark — spectators, seagulls; Stadiums —
   crowd idle sway + wave on big plays.
3. Apply the M15 lighting rig + M16 saturation pass wherever still dark/muddy.

**Proof:** for THREE venues, a slow 360° orbit recording showing dressed, lit,
moving environments on every side.

---

## 7. DEEP AUDIT — EXERCISE SYSTEM + AVATAR SYSTEM (M17/M20)

Run and REPORT (pass/fail each line, with evidence):
- [ ] Purchase 4-week plan (shards ledger entry) → scan → plan generates with ≥12
      exercises targeting the scan's actual deficits
- [ ] Every exercise in the plan plays its mini-movie on the USER'S avatar (no
      default-avatar leaks, no missing clips)
- [ ] "My scan vs target form" replay renders the user's own movement
- [ ] 12-week upsell purchasable; progressions differ from weeks 1–4
- [ ] Scan metrics land in System Scan profile + vertical_jump_log
- [ ] Closet: every face control (skin/hair/eyes/brows/nose/mouth/facial hair)
      visibly changes the preview; save persists; look renders in ≥2 game modes
      AND in workout movies
- [ ] Wearable purchase debits coins; card-skin equip verifies ownership;
      unowned card rejected server-side
- [ ] Delete-my-data clears scan + look; entitlement survives
- [ ] All flows work thumbs-only on a phone viewport

---

## ORDER & GLOBAL ACCEPTANCE
Order: 1 (gate) → 2 → 3 → 4 → 5 → 6 → 7 (audit last, after fixes).
Global: zero T-poses anywhere; ball trackable through the full eastbay; dunk
replay after every made dunk; dojo restored; scan is a diagnostic (no basketball);
snowboard has the lift grind + yeti chase; three venues pass the 360° orbit test;
audit checklist reported line-by-line with recordings.
