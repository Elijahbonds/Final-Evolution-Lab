# M66 — THE PIPELINE: batch gate, asset gate, live smoke test, CI, CLAUDE.md

Copy this into Abacus with every file in `files/`. All files NEW. Unlike
every other batch, **most of this belongs in the git repo, not in Abacus** —
see WIRING.

---

## ⚠ TOPOLOGY CORRECTION — read before wiring

The pipeline document assumes `git push → build → deploy` publishes the live
game. **It cannot, today.** I checked the repo:

- **No Babylon.js dependency anywhere** (`grep babylonjs` across every
  `package.json` → nothing). The game source is not in git.
- The only mode/TS source in the repo is under `docs/` — my batches.
- `frontend/` is a **Create React App** (`react-scripts 5.0.1`), a different
  app entirely. The live game serves `_next/static/chunks/…` — it's Next.js.
- There is no `vite.config`, no `next.config`, no root `tsconfig.json`, so
  `npm run build → vite build` would fail on the first run.
- There ARE two existing workflows (`fel-prebuild-ci.yml`,
  `firebase-deploy.yml`) — this one sits alongside them.

**The real topology:** Abacus owns the build and the deploy. This repo owns
the batches and the tooling. A `deploy.mjs` that "publishes to Abacus" would
require an Abacus deploy API I have no evidence exists — I'm not going to
invent one and hand you a script that can't work.

So this batch builds the pipeline **around the real topology**: everything
upstream of the drop is gated, and the live link is verified after it. When
the game source does move into the repo, the build/deploy job is ten
commented lines at the bottom of the workflow — the gates don't change.

## WHAT'S HERE, AND WHAT IT CAUGHT

**Every tool below was executed, not just written.**

| Tool | What it does | Verified |
|---|---|---|
| `tools/verify_batch.mjs` | Structure + syntax gate for a batch, before you drag it | Ran on all 55 batches. **Found a real TypeScript syntax error in the shipped M57 SynthKit.ts** — `KIT_META` opened with `= {` and closed with `];`, which would have failed the Abacus build. Fixed in this commit. |
| `tools/validate_assets.py` | Asset gate: tri budgets, KTX2, power-of-two, skeleton names | Ran against purpose-built GLB fixtures. Caught all 5 violation classes, passed the clean file, exited 1. Pure stdlib — parses GLB with `struct`+`json`, no Blender needed. |
| `tools/smoke.mjs` | Drives the LIVE link with a real browser after a drop | Same technique that has found every live bug in this project. |
| `tools/watch_assets.py` | The safe drag-and-drop inbox (conform → validate → ready/rejected) | Polls, no dependencies; degrades gracefully when Blender is absent. |
| `workflows/fel-pipeline.yml` | CI wiring the gates + a secret scan | Runs on `ubuntu-latest` today; one-line swap to the Mac mini runner. |
| `CLAUDE.md` | Standards that travel with the code | Carries the corrected skeleton spec. |

Two honest notes on the tooling itself:
- `verify_batch.mjs` skips `.tsx` for the brace check. JSX text carries
  apostrophes (`WHAT'S ON IT?`) that a non-JSX tokenizer reads as a string
  opener, and every `.tsx` false-flagged on the first run. A checker that
  cries wolf gets switched off, so it only claims what it can prove.
- The asset gate reads texture dimensions only when the exporter writes
  `extras.width/height`. Format and packing checks always run.

## THE SKELETON CORRECTION, AGAIN

The pipeline doc's gate spec says *"bones don't match the locked 65-bone
spec."* Both halves are wrong for FEL: the rig is **unprefixed**, and the
gate validates the **required-name set, not a count**. A count check rejects
a good rig with extra twist bones and accepts a 65-bone rig with names
nothing can resolve. `validate_assets.py` implements the name check and
rejects `mixamorig:` explicitly. Full rationale in `CLAUDE.md` and
`m65-avatar-system-phase0/AvatarSkeletonSpec.md`.

## FILES
| File | Goes where |
|---|---|
| `files/tools/verify_batch.mjs` | repo `tools/` |
| `files/tools/validate_assets.py` | repo `tools/` |
| `files/tools/watch_assets.py` | repo `tools/` |
| `files/tools/smoke.mjs` | repo `tools/` |
| `files/workflows/fel-pipeline.yml` | repo `.github/workflows/` |
| `files/CLAUDE.md` | repo root |

## WIRING
1. **Repo files** (everything above) go in the git repo at the paths shown.
   Nothing here is dragged into Abacus — this is the layer *around* Abacus.
2. `mkdir -p assets/{inbox,ready,rejected}` and add
   `assets/.work/` + `assets/rejected/` to `.gitignore`.
3. Local use, no CI needed:
   ```
   node tools/verify_batch.mjs docs/abacus-batches/m64-idle-pose-camera-fix
   python3 tools/validate_assets.py assets/ready
   node tools/smoke.mjs                      # after dropping into Abacus
   ```
4. Mac mini runner (optional, when you want CI on your own hardware):
   repo → Settings → Actions → Runners → New self-hosted runner (macOS),
   label it `self-hosted, macmini`, then change `runs-on: ubuntu-latest` to
   `runs-on: [self-hosted, macmini]` in the workflow. Install Node 20,
   Blender 4.x, and `pip3 install pillow` for the asset scripts.
5. The `watch_assets.py` inbox needs `fel_conform.py` from **M65** in the
   same `tools/` directory.

## ACCEPTANCE
1. `node tools/verify_batch.mjs --all` runs clean on every batch you intend
   to ship (4 pre-convention batches from m14–m22 will flag a missing
   `00-*.md` — that's accurate, they predate the convention).
2. Dropping a deliberately-bad GLB into `assets/inbox/` lands it in
   `assets/rejected/` with a `.reasons.txt`, never in `ready/`.
3. `node tools/smoke.mjs` drives the live link and writes screenshots +
   `smoke-report.json`, exiting 1 if any mode has a fatal console line.
4. The workflow runs green on push and fails on a committed test secret.
5. `CLAUDE.md` is at the repo root and states the UNPREFIXED bone rule.
