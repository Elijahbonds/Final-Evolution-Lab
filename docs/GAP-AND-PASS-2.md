# The gap, and the second pass

**Written after Phase 10 of the first pass.** Companion to
`docs/TEN-PHASE-PLAN.md` (pass 1) and `docs/BLUEPRINT.md`.

---

## Part 1 — The gap, stated plainly

Ten phases produced this:

| | |
|---|---|
| New core modules | 24 |
| Executable test suites | 22, all green |
| Assertions passing | **1,353** |
| Batch gate | clean |
| **Modes shippable** | **0** |
| **Criteria demonstrated (of 12)** | **2** |

Both halves are true. The logic is right and nothing reaches a player.

### The one sentence that explains it

> **Pass 1 was an authoring pass against a codebase I cannot see, and authoring
> was never the constraint.**

I said this in Phase 1 and then spent nine more phases proving it. `ModeKit`
exists so a mode can adopt five subsystems in twenty lines — and no mode has.
`SimulatableMode` exists so a match can be verified — and no mode implements
it. Eleven tells are specified — and zero are drawn. `fel_conform.py` has still
never been run.

### What that cost, honestly

Roughly 60,000 lines of batch code across 94 batches, of which I have watched
**zero** execute in the real app. Every batch since M74 ships with *"not
type-checked against the live source"* on it. That is not a caveat any more;
it's the defining property of the work.

### What it bought

Not nothing, and worth being fair about. The tests caught **six real bugs that
would have shipped silently**, each of the same shape — a system that runs,
unit-tests clean, and does nothing:

| phase | bug | consequence if shipped |
|---|---|---|
| 3 | reaction frames longer than the window they fit in | no rival could ever punish; mechanic dead |
| 4 | tennis court crossed in 0.83 s | pressure model inert |
| 5 | carve limit 6–8 m/s | carve state unreachable |
| 6 | ARV baseline included the tilt it detected | everyone scored exactly 50 |
| 7 | level 50 cost 50× level 1 | back half of progression a wall |
| 8 | simulate raw, record quantised | **Cash Arena rejects every honest player** |

Five of those were caught only because the tests assert *consequences* — "is
this state reachable at a realistic input?" — rather than values. That habit is
the most transferable thing pass 1 produced.

And three findings were about the existing product, not my code:

- **MRI was a constant.** `arv` and `esi` default to 50 and nothing overwrote
  them. Every player scored ~50 forever.
- **PRQ weight tables had drifted** between Swift and Python — five modes,
  one by 57%; browsing the shop minted PRQ like playing baseball.
- **`score` is client-supplied.** `POST {"score": 999999}` is an authenticated,
  server-computed reward.

### The blockers, ranked by how many modes they hold back

Every top blocker is **shared**, which is the actionable part:

| # | blocker | modes | who can clear it |
|---|---|:-:|---|
| 1 | No mode adopts `ModeKit` | 25 | Abacus, once |
| 2 | Zero of 11 tells drawn | 19 | art + shader work |
| 3 | `fel_conform.py` never run | 19 | **Mini only** (Blender) |
| 4 | No mode implements `SimulatableMode` | 8 cash modes | Abacus |
| 5 | App source not in the repo | everything | **Elijah → Abacus** |

Blocker 5 is the root of the other four. It has been open since M74.

---

## Part 2 — The second pass

**Pass 2 inverts pass 1.** Pass 1 wrote code and hoped it landed. Pass 2 moves
criteria from BUILT to PASS, with evidence, and writes as little new code as
possible.

> **Rule for the whole pass: no phase may add a new subsystem. Every phase must
> move at least one criterion to PASS on at least one real mode.**

| # | phase | moves to PASS | gate |
|---|---|---|---|
| **1** | **Sync + one mode** | — | `nextjs_space/` in the repo; `dunk` on `ModeKit`; a real `tsc` runs |
| 2 | Measure the baseline | boot, canvas | `integration_audit` on the live build; the first honest per-mode numbers |
| 3 | Lifecycle + movement | lifecycle, response | 20 route changes, no reload; hold W and *walk* |
| 4 | Mocap | no_tpose | Blender run once; `run`/`walk`/`idle_stand` conformed; `?probe=1` clean |
| 5 | Tells, wave one | legibility (6 modes) | basketball + combat mechanics visible |
| 6 | Tells, wave two | legibility (13 modes) | field, board, cognitive visible |
| 7 | PRQ + captions live | prq, a11y_audio | `[FEL-DDA]` on every boot; every cue captioned |
| 8 | `SimulatableMode` for the cash 8 | — | `proveDeterministic` green on 8 modes |
| 9 | Server verification | — | a real match re-simulated and matched end to end |
| 10 | Re-certify | framerate, fun | `certify.mjs` on real devices; the founder plays all 25 |

### What changes about how I work

**1. Nothing ships without an evidence artifact.** A screenshot, a console log,
a profile trace. "Tests pass" stopped being sufficient at Phase 3.

**2. One mode first, always.** Pass 1 built for 25 modes and integrated into
zero. Pass 2 does `dunk` end-to-end through every phase before touching the
second mode. If `ModeKit` has the wrong shape, I want to know at the cost of
one mode rather than twenty-five.

**3. Delete what doesn't earn its place.** Pass 2 should *shrink* the surface.
Some of the 24 new modules will turn out to be wrong once they meet a real
mode, and removing them is a legitimate outcome.

**4. The founder's playtest is a gate, not a report.** Criterion 10 is the only
one nobody else can score, and it's the one that decides whether any of this
was worth building.

### If only one thing happens

**Sync the app source.** `docs/ACCESS-SETUP.md` has the paste-ready request and
it has been open since M74. Every other item on this page is slower, riskier,
and partly guesswork until it lands.

Second: **run `tools/conform_clips.sh` once on the Mini.** One command,
one machine, and it unblocks nineteen modes.

---

## Part 3 — What I'd tell you if you asked whether this was worth it

Pass 1 found six bugs that would have shipped silently, three real defects in
the existing product, and produced a defensible design for every mode. It also
produced 60,000 lines nobody has run.

The design work was worth doing and did not need to be this large. **The right
version of pass 1 was Phase 1, Phase 2, and then integration** — proving
`ModeKit` on `dunk` before building nine more phases on an unproven contract.

I'd rather say that now than have it be the finding of pass 2.
