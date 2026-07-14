# Copilot Standing Instructions — Final-Evolution-Lab

STOP. Read this before writing any code.

You are working on Final-Evolution-Lab. Recent branches show five recurring
failure patterns. Each one has now cost real repair time. These are hard rules:

## BRANCH DISCIPLINE

**1. Branch from `origin/nexus/platform-core` — NEVER from `main`. Main is stale.**

Your last branch (`copilot/improve-engine-and-app`) forked from a July 6 main
and now conflicts with the canonical branch by ~479 lines in `App.js` alone.

Before starting: `git fetch && git checkout -b <branch> origin/nexus/platform-core`
returns 0, and run:

```
npx esbuild frontend/src/game/index.js --bundle --outfile=/dev/null \
  --external:@babylonjs/core --external:react --loader:.js=jsx
```

It must report **zero errors**.

**4. New code must be REACHABLE.** Every new module must be imported from an entry
point (a route, a registered mode, a CMake target). You shipped an entire
`frontend/src/game` tree that nothing imported — the build stayed green only
because webpack never parsed it.

- **C++:** every new `.cpp` goes in its `CMakeLists` target and the full gate
  must pass **before** commit:
  ```
  cmake -S . -B build-gate -DNEXUS_HEADLESS=ON && cmake --build build-gate -j8 \
    && ctest --test-dir build-gate
  ```
- **Web:** `npm run build` in `frontend/` must pass AND the new code must be
  reachable from a route you can name.

## SCOPE DISCIPLINE

**5. One branch = one deliverable.** Do not add story modes, board-game engines,
extra sport modes, agent subsystems, or "premium polish" to a branch scoped
to something else.

The project priority is the **PLAYABLE DUNK SLICE** at `/play/dunk`
(Babylon.js, `frontend/src/game`). The scope test for every commit:

> "Does this make the dunk loop more playable, more testable, or more fun?"

If **no** — it belongs on a separate branch with its own name, or nowhere.

**6. Honest commit messages.** `"feat: multiplayer P0/P1/P2 complete"` for a
stub-transport loopback is **not complete** — say `"local-only architecture,
stub transport"`. Do not mark work done that has never run. Do not tune
gameplay-feel constants (timing windows, spawn positions, score curves) —
those are reserved for Elijah; build the scaffolding and leave the numbers.

## BEFORE YOU FINISH

Run the verification matching what you touched:

- **Web:** `npx esbuild ...` gate + `npm run build` in `frontend/`
- **C++:** full cmake gate above

State in the PR description **exactly which gates you ran and their results**,
and list any file you created that is not yet reachable from an entry point.
Target: that list is **empty**.

---

*Append the actual task after this preamble when creating agent prompts, so
these discipline rules ride along with every assignment.*
