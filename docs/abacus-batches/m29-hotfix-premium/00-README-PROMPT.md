# M29 — CRITICAL HOTFIX + PREMIUM FEEL KIT

Copy this document into Abacus with every file in `files/`. Part 1 is a
**blocking hotfix for a live crash**. Part 2 is the premium-feel layer.

---

## PROMPT FOR ABACUS

### PART 1 — HOTFIX FIRST (the dunk mode is DOWN)

Live audit (July 2026, real browser): `/play/dunk` hangs on an infinite loading
spinner. Console shows the exact cause: **`BJS - Wrong sceneFilename parameter`**
— the Babylon migration IS live, but `CharacterLibrary` calls
`SceneLoader.LoadAssetContainerAsync('', '/models/elijah-hero.glb', scene)` and
Babylon rejects leading-slash filenames with an empty rootUrl. Two compounding
defects:
1. The loader call must split rootUrl/filename (`'/models/'` + `'elijah-hero.glb'`)
   and the glTF loader plugin must be registered (`import '@babylonjs/loaders/glTF'`).
   → `files/hotfix/CharacterLibrary.ts` (drop-in replacement).
2. `ModeHarness` had no failure path — any load error = spinner forever. The
   replacement (`files/hotfix/ModeHarness.ts`) wraps load in try/catch, adds an
   `'error'` phase with a retry callback, and a 20-second load watchdog. **No
   player must ever see an infinite spinner again.**
Deploy Part 1 immediately and verify: `/play/dunk` reaches READY, and a forced
bad URL shows the error screen with RETRY instead of hanging.

### PART 2 — PREMIUM FEEL (vision vs delivered audit)

What the live build has: hub/meta (good), Live tab (new ✓), Babylon runtime
(new ✓, crashed by Part 1 bug). What it does NOT yet feel like is the vision:
"best-selling game" premium. The audit gaps, with the file that closes each:

| Gap (vision doc) | Delivered today | Fix in this batch |
|---|---|---|
| Impact at key moments (M14/M16 juice) | None — dunks/KOs land silently | `JuiceKit.ts` — hit-stop, camera shake, world-space score pops, flash, slow-mo |
| Console boot/eject ritual (Shell 03 §1.2) | Hard route swaps, raw spinner | `BootSplash.tsx` — cartridge boot, venue art, READY gate, eject |
| Premium visual identity (M16 A2) | Utilitarian dark UI | `theme.css` — design tokens: type scale, glass panels, glow CTAs, gold/rarity accents |
| Haptics (Shell 03 §2.3) | None | `Haptics.ts` — button/impact/perfect patterns |
| Loading experience | Bare spinner (now a crash screen) | BootSplash doubles as the loading cover with progress + venue art |

Wire order: JuiceKit into DunkMode first (slam = hitStop 80ms + shake + "+3"
world pop + flash; replay already exists), then KarateEndless (KO), then
Football (evade/tackle). BootSplash wraps every `/play/*` route. theme.css
tokens replace ad-hoc colors on HUD/bezel/result screens. Haptics fire from
InputBus button-downs and JuiceKit impacts.

## ACCEPTANCE
1. HOTFIX: dunk loads to READY on the live URL; forced-fail shows error+retry;
   20 s watchdog proven.
2. Recorded dunk make: hit-stop + shake + world-space "+PTS" pop + flash, then
   replay. Recorded karate KO: hit-stop + shake + KO banner.
3. Every /play route opens with the boot splash (venue art + progress + INSERT
   → READY) and ejects back to the hub with the wipe. No raw spinners anywhere.
4. HUD/result screens use the tokens (check: no #hex literals left in mode HUD
   markup) — visibly richer typography/panels on phone at arm's length.
5. Phone: button taps vibrate (10 ms), slams vibrate the triple pattern.
