# Game Modes vs. Inspirations: Comparison, Plan, and Revisions

Per-mode comparison to **NBA 2K**, **NBA / NFL / FIFA Street**, **Big Brain Academy**, **Naruto Storm × Matrix Revolutions**, **Wii Sports / Resort**, and **NBA Live 06/07**. Then: what to implement so each mode feels and looks closer to its reference(s), with analyze → plan → build → assess → revise.

---

## 1. Mode-by-Mode Comparison

### Basketball: Head to Head (1v1)

| Aspect | Inspiration (NBA 2K / NBA Street) | Current FEL | Gap |
|--------|-----------------------------------|-------------|-----|
| **Gameplay** | 1v1 iso, shot meter, contest, dribble moves | Tap to commit; PRQ-driven outcome; no shot meter, no contest phase | No possession, no defender contest, no shot meter; single “commit” per round |
| **Look** | Court, two avatars, hoop, broadcast-style or follow cam | Gradient + HUD, PS2 overlay, round/score; no 3D court in Arena | Arena is UI-only; no 2 avatars, no court in play view |
| **Feel** | Shot timing, green release, contest affecting make % | PRQ band 0.62–0.90 → PERFECT/GOOD/MISS; haptic by mode | Feels “commit and see”; no timing skill, no contest interaction |

**Implementation plan (priority):**
1. **Presentation:** Keep “Venice Beach” + street copy; add inspiration tag “NBA Street style” on Get Ready or mode card.
2. **Mechanics (later):** Optional “contest” phase: after commit, opponent has a brief window to “contest” (tap/stick) that reduces make chance; or keep as-is and lean on PRQ + copy.

---

### Basketball: Dunk Contest

| Aspect | Inspiration (NBA Live 06/07, NBA Street) | Current FEL | Gap |
|--------|-----------------------------------------|-------------|-----|
| **Gameplay** | Runway, gather, jump, style buttons (△□○✕), judge scores, flair | Lab: sprint → launch → airborne (face buttons) → landing; Arena solo → “Open Lab” interstitial | **Lab matches well.** Arena (solo) routes to Lab; local play still generic tap. |
| **Look** | Runway, crowd, judges, style meter | RealityKit court, PS2 overlay, judge overlay, modifiers, impact | Matches Live 07–style in Lab. |
| **Feel** | Timing in green zone, style variety, “SLAM” satisfaction | Phase-based, face-button finishers, judge score, shards | Close to inspiration in Lab. |

**Implementation plan:**
1. **Done:** Arena solo → Lab 3D court via interstitial.
2. **Presentation:** Subtitle/card already says “NBA Live 07–style”; ensure Get Ready keeps “Sprint → Gather → Fly. Face buttons for finishers.”
3. **Optional:** More trick variety or judge callouts in Lab.

---

### Basketball: 3v3 Streetball

| Aspect | Inspiration (NBA Street) | Current FEL | Gap |
|--------|---------------------------|-------------|-----|
| **Gameplay** | 6 on court, possession, passes, dunks, street moves | Tap to commit per round; no 3v3 scene, no possession | Same as 1v1: round-based commit, no court, no team AI. |
| **Look** | Street court, 6 characters, Venice/cage vibe | Same gradient + HUD as 1v1; “3v3” in name only | No 3v3 scene or avatars. |
| **Feel** | Team ball, momentum, “run the court” | Per-round PRQ outcome; no team feel | Feels like 1v1 with different label. |

**Implementation plan:**
1. **Presentation:** Copy and tag “NBA Street style”; differentiate from 1v1 in atmosphere text (“Run the court. Three on three.”).
2. **Mechanics (later):** 3v3 scene + possession/defense is a large build; keep as round-based until dedicated scene exists.

---

### Karate

| Aspect | Inspiration (Naruto Storm, Matrix) | Current FEL | Gap |
|--------|-----------------------------------|-------------|-----|
| **Gameplay** | Combos, block, specials, cinematic hits | Tap to commit; PRQ outcome; no combos, no block phase | Single strike per “bout”; no combo/block. |
| **Look** | Dojo/arena, two fighters, hit VFX, style | Gradient + HUD; “Dojo Arena” in name; no 3D dojo in Arena | No dojo scene, no fighter models in play. |
| **Feel** | “One clean point,” respect, impact | PERFECT/GOOD/MISS; heavy haptic for perfect; copy “Respect. Control.” | Feel is abstract; no strike animation or impact moment. |

**Implementation plan:**
1. **Presentation:** Add inspiration tag “Storm × Matrix style” or “Dojo respect”; keep “One clean point at a time” and “Bout” language.
2. **Mechanics (later):** Block/contest window or combo chain would require new phase logic; optional hit VFX when commit resolves.

---

### Baseball (Home Run Derby)

| Aspect | Inspiration (Wii Sports Baseball) | Current FEL | Gap |
|--------|------------------------------------|-------------|-----|
| **Gameplay** | Swing timing (or motion), pitch, contact, ball flight | Tap to commit; PRQ outcome; inputScheme = .swipe but UI is tap | No pitch, no swing motion, no ball; same as other Arena modes. |
| **Look** | Stadium, pitcher, batter, ball, fence | Gradient + HUD; “Stadium Diamond” in name | No diamond or ball in Arena. |
| **Feel** | “Clear the fences,” derby tension | Copy “Clear the fences”; no swing feedback | No sport-specific interaction. |

**Implementation plan:**
1. **Presentation:** Tag “Wii Sports style”; keep “At-bat” and derby copy.
2. **Mechanics (later):** Swipe-to-swing or power + timing in a dedicated view; pitch/ball in scene (see GAMEPLAY_IMPROVEMENTS_PLAN).

---

### Football (Kick Return)

| Aspect | Inspiration (NFL Street, sudden death) | Current FEL | Gap |
|--------|---------------------------------------|-------------|-----|
| **Gameplay** | Returner + defenders, evade, tackle radius, one return | Tap to commit; PRQ outcome; no return scene | No field, no returner/defenders. |
| **Look** | Field, yard lines, returner, ball | Gradient + HUD; “Stadium Field” in name | No field in Arena. |
| **Feel** | “House call” / “Stopped” | Copy supports it; no run/evade feel | Abstract round. |

**Implementation plan:**
1. **Presentation:** Tag “NFL Street style”; keep “One return. No second chances.” and “Drive.”
2. **Mechanics (later):** Kick return scene with homing defenders (see GAMEPLAY_IMPROVEMENTS_PLAN).

---

### Soccer (Penalty Shootout)

| Aspect | Inspiration (FIFA Street, Wii Resort) | Current FEL | Gap |
|--------|--------------------------------------|-------------|-----|
| **Gameplay** | Aim + power, keeper read, ball trajectory | Tap to commit; PRQ outcome; inputScheme = .penaltyKick but UI tap | No aim, no keeper, no ball. |
| **Look** | Pitch, spot, goal, keeper | Gradient + HUD; “Stadium Pitch” in name | No pitch or goal in Arena. |
| **Feel** | “You vs the keeper,” pressure | Copy “You vs the keeper”; no penalty interaction | Abstract round. |

**Implementation plan:**
1. **Presentation:** Tag “FIFA Street / Resort style”; keep “Penalty” and 5 rounds.
2. **Mechanics (later):** Aim + power swipe and ball flight in dedicated view.

---

### Golf (Closest to Pin)

| Aspect | Inspiration (Wii Sports Golf) | Current FEL | Gap |
|--------|--------------------------------|-------------|-----|
| **Gameplay** | Power bar + direction, wind, green | Tap to commit; PRQ outcome; inputScheme = .swipeGolf but UI tap | No power arc, no green, no shot. |
| **Look** | Green, pin, ball, sky | Gradient + HUD; “Golf Green” in name | No green in Arena. |
| **Feel** | “Closest to the pin,” one swing per hole | Copy and “Hole” label; no swing feel | Abstract round. |

**Implementation plan:**
1. **Presentation:** Tag “Wii Sports style”; keep “Hole” and 3 holes.
2. **Mechanics (later):** Swipe power + direction and green target in dedicated view.

---

### Tennis & Volleyball (Rally Ace)

| Aspect | Inspiration (Wii Sports / Resort) | Current FEL | Gap |
|--------|-----------------------------------|-------------|-----|
| **Gameplay** | Drag to aim, tap to hit, rally flow | Tap to commit; PRQ outcome; inputScheme = .rallyAce but UI tap | No drag aim, no rally. |
| **Look** | Court, net, ball | Gradient + HUD; “Venice Beach” / “Beach Court” | No court in Arena. |
| **Feel** | “Serve, rally, finish” / “Drag to aim, spike” | Copy supports it; no aim/hit interaction | Abstract round. |

**Implementation plan:**
1. **Presentation:** Tag “Wii Sports / Resort style”; keep “Point” and rally copy.
2. **Mechanics (later):** Drag-to-aim + tap-to-hit in dedicated view.

---

### Gymnastics

| Aspect | Inspiration (Mario & Sonic Olympics) | Current FEL | Gap |
|--------|-------------------------------------|-------------|-----|
| **Gameplay** | Rhythm tap or timing, apparatus, dismount | Tap to commit; PRQ outcome; inputScheme = .rhythmTap but UI tap | No rhythm sequence, no apparatus. |
| **Look** | Arena, apparatus, mat | Gradient + HUD; “Arena” in name | No apparatus in Arena. |
| **Feel** | “Stick the landing,” form | Copy “Stick the landing”; routine/dismount language | Abstract round. |

**Implementation plan:**
1. **Presentation:** Tag “Mario & Sonic Olympics style”; keep “Routine” and “Stick the landing.”
2. **Mechanics (later):** Rhythm tap sequence or timing bar for dismount.

---

### Brain Brawl

| Aspect | Inspiration (Big Brain Academy, Coursebox AI) | Current FEL | Gap |
|--------|----------------------------------------------|-------------|-----|
| **Gameplay** | Quiz, first correct wins, difficulty tiers, time pressure | 5 questions, tap to lock answer, first correct wins vs AI; curriculum-based | **Close:** quiz UI, AI opponent, first-to-answer. |
| **Look** | Clean quiz UI, brain/learning theme | Question card, choices, correct/wrong feedback, PRQ/shard reward | Matches “Big Brain” style. |
| **Feel** | Quick thinking, “your curriculum” | Subtitle “Big Brain × Coursebox AI”; attribute label on result | Could add difficulty label or timer hint for more “Academy” feel. |

**Implementation plan:**
1. **Presentation:** Ensure “Big Brain × Coursebox AI” and “First correct wins” are visible; optional difficulty or time-pressure hint.
2. **Content:** More questions per track/difficulty (existing roadmap).

---

## 2. Prioritized Implementation Plan

**Tier 1 – Presentation (fast, high signal)**  
- Add **inspiration tag** per mode (e.g. “NBA Street style”, “Wii Sports style”, “Storm × Matrix style”) on Get Ready or mode card so each mode is explicitly tied to its reference.  
- Keep and reinforce existing **atmosphere and round copy** (already in GameModeId).  
- **Assess:** Do one build pass that adds a short inspiration line per mode and verify in Get Ready / Arena list.

**Tier 2 – Feel (no new scenes)**  
- **Per-mode haptic** (done in a previous pass).  
- **Sound** (system sounds done).  
- Optional: **contest/block phase** for 1v1 or Karate (single extra tap window that modifies outcome).  
- **Assess:** Playtest 1v1, Karate, Brain Brawl; note if “contest” or “block” is worth implementing.

**Tier 3 – Sport-specific input (medium effort)**  
- **Baseball:** Swipe-to-swing view with timing window (no full scene).  
- **Soccer:** Aim + power for penalty (simple overlay).  
- **Golf:** Power arc + direction (simple overlay).  
- **Assess:** Pick one (e.g. Golf or Soccer) and implement one dedicated mini-view; measure feel vs generic commit.

**Tier 4 – Scenes and full mechanics (large effort)**  
- 3v3 court with 6 avatars; possession/defense.  
- Karate dojo with two fighters and hit VFX.  
- Football return with homing defenders.  
- **Assess:** Defer until Tier 1–3 are done; then scope one scene (e.g. 3v3 or dojo).

---

## 3. Build (This Pass) — Done

- **Added inspiration tag per mode:** `GameModeId.inspirationTag` returns: NBA Street style (1v1, 3v3), NBA Live 07 style (Dunk), Storm × Matrix style (Karate), Wii Sports style (Baseball, Golf), NFL Street style (Football), FIFA Street style (Soccer), Wii Resort style (Tennis, Volleyball), Olympics style (Gymnastics), Big Brain Academy style (Brain Brawl).  
- **Surfaced in UI:**  
  - **Get Ready:** Optional `inspirationTag` shown as a capsule pill under the subtitle (accent color, monospaced). Arena passes `mode.id.inspirationTag`; Lab dunk passes `"NBA Live 07 style"`.  
  - **Arena mode list:** Each mode row shows the tag under the subtitle in small monospaced accent text.  
- **Assess:** Each mode now has an explicit “this is like X” reference on both the selection card and the Get Ready screen.  
- **Revisement:** See §4.

---

## 4. Assessment and Revisement

**Assessment (after build):**  
- Inspiration tags give each mode a clear “this is like X” signal without changing mechanics.  
- Gap between “tap to commit” and reference games remains for sports that need swipe/aim/rhythm; that’s documented in Tier 3–4.  
- Brain Brawl and Dunk (Lab) are already closest to their inspirations; tags reinforce that.

**Revisement (next steps):**  
1. **Tier 2:** Add optional contest/block phase for 1v1 or Karate if playtests show demand.  
2. **Tier 3:** Implement one sport-specific input (e.g. Golf power arc or Soccer aim) in a dedicated mini-view.  
3. **Tier 4:** Keep for when 3D scenes are in scope (Unreal or expanded SceneKit/RealityKit).  
4. **Doc sync:** GAMEPLAY_STATUS and POLISH_PLAN reference this doc for mode-inspiration alignment.

---

## 5. Summary Table

| Mode | Inspiration(s) | Gameplay gap | Look gap | Plan (this pass) |
|------|----------------|--------------|----------|-------------------|
| Head to Head | NBA 2K, NBA Street | No contest, no meter | No court in Arena | Tag “NBA Street style” |
| Dunk Contest | NBA Live 07, NBA Street | Lab matches; Arena → Lab done | Lab matches | Keep copy; tag “NBA Live 07 style” |
| 3v3 | NBA Street | No 3v3, no possession | No court | Tag “NBA Street style” |
| Karate | Storm, Matrix | No combo/block | No dojo | Tag “Storm × Matrix style” |
| Baseball | Wii Sports | No swing/pitch | No diamond | Tag “Wii Sports style” |
| Football | NFL Street | No return scene | No field | Tag “NFL Street style” |
| Soccer | FIFA Street, Resort | No aim/keeper | No pitch | Tag “FIFA Street style” |
| Golf | Wii Sports | No power/direction | No green | Tag “Wii Sports style” |
| Tennis / Volleyball | Wii Resort | No drag/tap rally | No court | Tag “Wii Resort style” |
| Gymnastics | Mario & Sonic Olympics | No rhythm/apparatus | No apparatus | Tag “Olympics style” |
| Brain Brawl | Big Brain Academy | Close | Close | Tag “Big Brain Academy style” |
