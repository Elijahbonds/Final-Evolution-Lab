# The one-shot build prompt

**Give this to Claude Code on the Mac Mini.** Paste the block in §2 verbatim.

---

## §1 — Read this part yourself first (Elijah)

You asked whether I could one-shot build the app. Straight answer, so you can
plan around it rather than discover it:

**No agent can, and it is worth knowing exactly why.** The Babylon/Next.js app
is not in this repo. It lives inside Abacus. I have never read a single line of
the code that is actually running — every fix I write is aimed at a contract
inferred from my own earlier batches. That has already cost real defects:
duplicate tennis and volleyball modes, an art-card function that looked for a
mesh name no venue builds, six live routes reported as broken.

So "one shot" splits into two honest questions:

**Can the foundation be built in one pass?** Yes — and it is done. **M81**
ships the four layers under every mode: movement, engine lifecycle, PRQ-driven
difficulty, and the canvas. 157 tests pass by execution. That is the single
largest quality change available to this product, and it is written.

**Can the whole app be built in one pass?** No, and not because of effort.
Three things genuinely cannot be one-shot:

1. **Mocap.** `tools/fel_conform.py` needs Blender. Only the Mini has it. No
   amount of prompting substitutes for running it once.
2. **Feel.** `MotionModel`'s constants are industry-standard starting points,
   not values tuned against this game. Somebody has to hold a phone and move
   them. That somebody is you — bar 10 of §7 in `docs/BLUEPRINT.md` is the one
   check no agent can score.
3. **The app source.** Until `nextjs_space/` is in the repo, every batch ships
   with "not type-checked against the live source" on it. That is a standing
   disclaimer on everything, and it only lifts one way.

What the Mini *can* one-shot is everything in §2: integrate M80 and M81,
conform the first mocap clips, wire the six unrouted modes, and verify all of
it. That is Waves 0 and 1 of `docs/BLUEPRINT.md` in a single sitting.

---

## §2 — Paste this to Claude Code on the Mini

> You are Claude Code on the Mac Mini, working on Final Evolution Lab at
> `/Users/elijahbonds/Final-Evolution-Lab`. You are one of three agents. The
> other two are Claude Code in a cloud container (playtests the live site, no
> local disk, no deploy) and Abacus AI (owns and deploys the live Next.js app,
> currently outside version control).
>
> **Read these first, in this order:**
> 1. `docs/AGENT-ACCESS-AND-PROTOCOL.md` — who writes where, and the journal
>    protocol. Follow it.
> 2. `docs/BLUEPRINT.md` — the full build plan.
> 3. Run `node tools/agent_sync.mjs claude-mini` — open requests addressed to
>    you.
>
> Then do the following. Work on branch `mini/wave-1`, branched from `main`.
> Commit after each numbered item. Append one journal entry per item to
> `docs/agents/journal/claude-mini.md` in the documented format.
>
> **1 — Confirm or refute the engine-leak diagnosis. Do this before writing
> any code.** `docs/BLUEPRINT.md` §1.1 has a console snippet that counts WebGL
> context allocations. Open the live app, paste it, navigate between eight
> modes without reloading, and record the count. If it climbs past ~8 and the
> game goes black, the diagnosis holds and M81's harness is the fix. If it
> stays at 1–2, the cause is a Next.js remount instead — say so plainly and do
> not apply the harness change as if it were the fix. **Report the number
> either way.** An inferred cause that nobody checks is how the last audit went
> wrong.
>
> **2 — Run the mocap pipeline end to end. Nothing else in the fleet can do
> this.**
> - `brew install --cask blender`, then
>   `export BLENDER=/Applications/Blender.app/Contents/MacOS/Blender`
> - Take one DeepMotion or Meshy export. Run
>   `node tools/clip_check.mjs <file>` FIRST. It will almost certainly report
>   PREFIXED bone names. Record the output — that confirms the diagnosis on a
>   real file rather than on my say-so.
> - `bash tools/conform_clips.sh <in-dir> assets/ready/anim`
> - Re-run `clip_check.mjs`. Rename each output to a clip id from
>   `anim/clipManifest.ts` — the filename **is** the contract; a file the
>   manifest does not name is never requested and fails silently.
> - Start with `idle_stand`, `run`, `walk`, `strafe_left`, `strafe_right`.
>   They play in every mode. One good run cycle changes the whole product; one
>   good dunk changes one screen.
> - If `fel_conform.py` fails, fix it. It has never been executed anywhere —
>   it is written against the Blender 4.x API and unproven. Fixing it is
>   expected work, not a blocker.
>
> **3 — Answer the open question in `docs/BLUEPRINT.md` §1.2i: is movement
> camera-relative?** Search whatever app source you can reach for where mode
> code turns `Intent.moveX/moveY` into world motion. If input maps to world
> axes rather than the camera basis, that is likely the single largest
> contributor to "I don't feel in control" and it outranks everything else in
> the movement fix. Report which it is.
>
> **4 — Verify M80 and M81 by execution, and be adversarial about it.**
> ```
> node docs/abacus-batches/m80-external-animation/files/tests/clip_check_test.mjs   # 21
> cd docs/abacus-batches/m80-external-animation/files && node --experimental-strip-types tests/anim_test.ts   # 46
> cd docs/abacus-batches/m81-feel-foundation/files && node --experimental-strip-types tests/motion_test.ts    # 61
> cd docs/abacus-batches/m81-feel-foundation/files && node --experimental-strip-types tests/foundation_test.ts # 96
> node tools/verify_batch.mjs --all
> node tools/agent_sync.mjs --check
> ```
> Then **review the code, do not just run the tests.** I wrote it without ever
> seeing the app it plugs into. Three things I would check first:
> - `ModeHarness.ts` assumes `ctx.camDirector.yawDeg` exists. It may not.
> - `ModeHarness.ts` imports `LoadAssetContainerAsync` semantics from Babylon
>   8; if the app is on 7 the M80 loader needs `SceneLoader.LoadAssetContainerAsync`.
> - `MotionModel` and `PlayerSlot` must not both decide `sprint`. If
>   `LocalInputSource` still derives it from stick magnitude, M81 does nothing.
>
> If you find a mistake, fix it and say so in your journal entry. Do not paper
> over it.
>
> **5 — Route the six finished modes.** `dance`, `art`, `acting`, `irl`,
> `brain_brawl`, `who_scene_it` are complete, tested modules behind six missing
> route strings (`core/modeRoutes.ts`, M79). This is the cheapest quality win
> in the project. If you cannot reach the app's router, write the exact patch
> and leave it as a `NEEDS: abacus` entry.
>
> **6 — Report honestly.** Tag every claim VERIFIED (you ran it), INFERRED
> (reasoned from code you read), or ASSUMED (could not check). The last audit
> was wrong because inferred was reported as verified. If something is blocked,
> finish everything else and say exactly what you left and why.
>
> **Constraints, all non-negotiable:**
> - Never commit `.env*`, `GoogleService-Info.plist`, Firebase service-account
>   JSON, `smoke-state.json`, or any key.
> - Zero external game assets. Venues are procedural; characters original.
>   Named commercial games inform mechanics only — never assets, code,
>   character names, or visual motifs.
> - Do not push to `claude/nexus-engine-setup-2qgkik` or `abacus/*`.
> - Do not open a pull request unless Elijah asks.

---

## §3 — And this to Abacus

> Please integrate two batches, in this order.
>
> **M80 — external animation.** New files under `anim/`, plus two tools. Wiring
> is in its README: serve `assets/ready/anim/` at `/assets/ready/anim`, and
> call `loadClipPack()` at character setup **after** the procedural clips are
> registered, so external clips override rather than lose. The game must play
> perfectly with that folder empty — a missing clip degrades to procedural and
> never breaks a mode.
>
> **M81 — the feel foundation.** Replaces `core/InputBus.ts` and
> `core/ModeHarness.ts`, adds `MotionModel`, `inputCore`, `Teardown`, `DDA` and
> `styles/game-surface.css`. **One breaking change:** `runMode()` is no longer
> `async` — it returns a handle synchronously so `dispose()` is reachable during
> load. That ordering is the entire fix for "you have to refresh the page to
> load a game". `runModeLegacy()` restores the old signature if you need to
> stage the migration; it warns, because it also restores the bug.
>
> Two things in M81 will do nothing unless you also change them:
> - `PlayerSlot.LocalInputSource` must stop deriving `sprint` from stick
>   magnitude and read L1/Shift instead. Leaving that line cancels most of the
>   batch.
> - Mode movement must pass the camera yaw into `step()`, or movement stays
>   world-relative.
>
> **Then, please:** confirm which major version of Babylon the app is on, and
> append what you integrated and what broke to `docs/agents/journal/abacus.md`
> — three lines is enough. Two of the three agents on this project currently
> cannot see any of your changes.
>
> And separately, the request in `docs/ACCESS-SETUP.md` still stands: syncing
> the app source into the repo is the single change that makes every future
> batch type-checked instead of inferred.
