# Dunk first

**The decision, 2026-07-28: one mode, one stack, to real players.** Everything
else is frozen until the dunk contest is something strangers want to play twice.

This replaces the 25-mode plan as the active roadmap. `docs/PASS-2-RESULTS.md`
is why.

---

## Where dunk actually stands

`node tools/dunk_gate.mjs` — one command, run against the deployed build:

```
  ok canvas coverage          79.8%  (want >= 55%)
  ok backing pixel ratio         4x  (want <= 4x)
  NO character on screen       8.2%  (want >= 15%)
  NO character size             46px  (want >= 100px)
  NO live regions                0   (want >= 2)
  NO mesh not welded          23.3%  (want >= 60%)
  ok survives unattended         0   (want 0 grounding faults)

  3/7 checks pass.
```

**Two of those went green since this morning.** The canvas was 26.2% coverage
and a 9.01× backing buffer; it is now 79.9% and 4×. M95 shipped. That is the
first batch in this whole engagement to reach production and be measured
working, and it is the proof that the small-drop approach lands where the big
one did not.

## What is left, and it is small

| # | fix | size | who | unblocks |
|---|---|---|---|---|
| 1 | **Camera: dunk radius 14 → 3.0** | one number | Abacus | character 8.2% → 21%, 46px → ~150px |
| 2 | **Mount `<CaptionRegion />`** | 2 files | Abacus | live regions 0 → 2 |
| 3 | **Prefix bug: fix and shipped** | done | — | conform pipeline no longer silently fails on FEL's own mesh |
| 4 | **Find and fix whatever produces the deployed 18,409-vert `Body_c5`** | unknown | Mini | the arms can move at all |

### Item 3 is done — and it redirects item 4

M104 downloaded FEL's actual base mesh and confirmed `mixamorig10:` — not
`mixamorig:` or `mixamorig1:` — is its real bone prefix. All three copies of
FEL's strip-prefix rule (`boneNames.ts`, `clip_check.mjs`, `fel_conform.py`)
missed it; `fel_conform.py`'s own health check would have reported this exact
asset as `conforms: True` while every bone lookup against it silently failed.
Fixed, tested against the real prefix, zero regressions across 33 suites.

**What M104 did NOT confirm: that the raw downloaded asset is where the
T-pose bug lives.** The one region directly checked — the jacket's sleeve,
which has geometry running the full arm to the wrist — was **already
correctly bound to arm bones, 100%**, before any repair. And the raw asset's
vertex count (20,431 across four pieces) does not match the 18,409 M98
measured on the live, deployed, single-mesh character. Something between
"raw Mixamo download" and "what the game actually renders" changes the mesh,
and that is where item 4 needs to look — not at re-running the same download.

`tools/glb_reskin.mjs inspect <file.glb>` gives the M98 measurement offline,
in about a second, the moment the actual deployed asset can be extracted.
Do that first, before opening Blender.

### Why the camera and the mesh are the same fix

They fail together regardless of where the mesh bug turns out to live. The
character is 46 CSS pixels tall, and at that size a correctly-rigged arm and
a welded one are the same picture — it is what made the T-pose get
misdiagnosed twice already. Fixing the camera without fixing the mesh gives
you a **large** broken character. Fixing the mesh without the camera gives
you a correct character nobody can see.

Do both before judging whether it looks right.

## Definition of done

Dunk ships when:

1. `node tools/dunk_gate.mjs` → **7/7**.
2. **Twenty strangers play it for ten minutes** on their own phones.
3. More than half of them start a second contest without being asked.

Point 3 is the only one that matters. The other two are how you avoid wasting
their time.

## Tier 1 — ship this

`docs/abacus-batches/dunk-tier1/` — **8 files, 1,042 lines, zero external
dependencies.** Four of the five modules import nothing at all.

That number is the whole point. The previous integration path was 24 zips in a
strict order with a cross-batch dependency graph, and none of it landed. This
is one folder.

## Tier 2 — do not build this yet

`DunkSim`, `ModeKit`, replays, determinism, server-side verification. Roughly
**700 lines that drag in six more batches** (M48, M83, M84, M85, M91, M92).

It is good work — M102 proves a real match re-simulates and matches end to
end — and it buys exactly one thing: **prize money**. Prize money is worthless
until people want to play the game twice. It waits for the twenty strangers.

If they come back, tier 2 is a week. If they don't, tier 2 was never the
problem.

## Frozen

Not deleted. Tagged, archived, and not paid for:

- **iOS / Swift** — 278 files
- **Unreal / C++** — 126 files
- **The other 24 modes**
- **90 of the 91 batch folders**

If the web dunk contest works, these become real options again. If it doesn't,
none of them would have saved it.

## The rule for what comes next

> **Nothing gets built for mode two until mode one has twenty players.**

The failure this project has repeated is building breadth against a product
nobody has measured. Pass 1 produced 61,359 lines and integrated zero. Pass 2
produced ~1,500 and shipped one thing that worked. The difference was not
effort or care — it was whether the thing being built and the thing being
measured were the same artifact.

## Commands

```bash
node tools/dunk_gate.mjs              # the scorecard — is dunk shippable
node tools/dunk_gate.mjs --desktop    # the same, on a desktop viewport
node tools/pose_probe.mjs             # character size and pose, inside the running game
node --experimental-strip-types tools/skin_audit.mjs   # can the mesh animate at all
```

All four read the deployed app. None of them measures this repo.
