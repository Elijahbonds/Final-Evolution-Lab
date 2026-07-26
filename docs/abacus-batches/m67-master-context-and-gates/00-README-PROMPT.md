# M67 — MASTER CONTEXT (corrected) + the three gates the brief revealed were missing

Copy this into Abacus with every file in `files/`. All files NEW.
`MASTER-CONTEXT.md`, `walletCore.ts` and `deploy.mjs` belong in the **git
repo**; `PerfMonitor.ts`, `readyMarker.ts` and `GenerationService.ts` go into
the **game source** in Abacus. Paths in WIRING.

---

## ⚠ THE SKELETON SPEC — RAISED FOR THE THIRD TIME

The brief's §4.1 again specifies `mixamorig:Hips` and *"preserve mixamorig:
prefix throughout"*, and states it supersedes prior framing. **A document
cannot supersede a property of the deployed rig.** The live FEL skeleton is
**UNPREFIXED**.

Adopting the brief's version makes every authored clip resolve zero bones —
characters freeze at bind pose across all 23 modes, GroundLock stops
clamping, and the symptom is indistinguishable from the T-pose bug that took
several diagnostic cycles to find. **This exact error has already been made
once and caught once**, in M28's `mirroredClips.ts`, which carries the
written correction.

I have not silently complied and I have not silently ignored it: the
corrected spec, the five pieces of evidence, and the "names not counts"
validation rule are all in `MASTER-CONTEXT.md`, which is written to be the
repo's canonical copy so the error stops propagating. Two smaller conflicts
are corrected there too — the mode contract is `ModeDefinition`, not
`IGameMode`, and the deploy topology (§5A) assumes a build this repo cannot
perform.

Everything else in the brief — the strategy, the firewall, the wave order,
the budgets, the compliance register — I agree with and have built to.

## WHAT THE BRIEF REVEALED WAS MISSING

Reading it against what's actually shipped surfaced three real gaps. All
three are Wave-0/Wave-1 items, and one is a **hard compliance gate**.

### 1. Server-authoritative wallet — the gate nothing had behind it
The firewall says *"server-authoritative wallet precedes any payment or
ownership."* It didn't exist. The Studio (M57) and Marketplace (M60) both
call a `spendShards` seam with **nothing authoritative behind it** — a
client could grant itself anything. `economy/walletCore.ts` is that
authority:
- **Lab Credits are earned-only, enforced in code.** There is no path that
  credits LC for money — a set of permitted earn-reasons rejects anything
  else. That separation is what keeps LC outside real-money-transfer
  regimes; it is not cosmetic.
- **Every mutation is idempotent** on a caller-supplied key, so webhook
  retries and double-clicks cannot double-charge or double-grant.
- **Append-only ledger; balances are derived state.** `audit()` proves
  balance == sum(ledger) and `reconcile()` repairs drift — ledger writes
  land before balance writes precisely so a crash loses nothing.
- `makeSpendShards(wallet, userId)` matches the exact prop signature the
  Studio and Marketplace already take, so wiring it makes those features
  authoritative with **no UI change**.

### 2. Frame monitor — Wave 1 says build this FIRST
`core/PerfMonitor.ts`. Measurement before optimization, because most
optimization guesses are wrong. Tracks frame time (avg **and worst-in-window
— a dunk that averages 60fps but spikes at the flush feels broken**), draw
calls, active meshes, texture VRAM, long-frame count, and budget violations.
The one built specifically for this game: **shader compiles during
gameplay**. Babylon compiles lazily on first visibility, so a new cosmetic
entering frame mid-dunk hitches at exactly the wrong moment — any compile
while playing is counted and logged as a defect, and `warmAll()` pre-warms
every material on the loading screen. Dev-only; costs nothing in production.

### 3. Generation-service seam — Wave 2 permits exactly this and no more
`platform/GenerationService.ts`. One interface, vendors behind adapters, so
owning a model later is a one-file change instead of a rewrite. It ships
**no vendor keys, endpoints or payloads** — I have credentials for none of
them, and an invented request body produces code that fails on first call.
The default adapter reports precisely what each vendor needs. This adds an
interface, not a capability, which is why it doesn't violate the firewall.

## THE TWO STUBS §5A FLAGGED
- **`core/readyMarker.ts`** — the `#dunk-ready` marker the smoke test waits
  for, generalized to every mode. It distinguishes **loaded** (geometry
  exists) from **playing** (loop running) — a smoke test that passes on
  "loaded" green-lights a mode that never starts.
- **`tools/deploy.mjs`** — gates → archive → package a timestamped verified
  bundle → publish *if* an adapter exists. It is a packager rather than an
  API call because there is no public Abacus deploy API; a
  `publishToAbacus()` against an invented endpoint would fail on first run
  while looking correct. Rollback is a folder copy, not a rebuild.

### FILES
| File | Goes where |
|---|---|
| `MASTER-CONTEXT.md` | repo `docs/` — **the canonical brief** |
| `files/economy/walletCore.ts` | server source (framework-agnostic, injected `Db`) |
| `files/core/PerfMonitor.ts` | game source `core/` |
| `files/core/readyMarker.ts` | game source `core/` |
| `files/platform/GenerationService.ts` | game/server source `platform/` |
| `files/tools/deploy.mjs` | repo `tools/` |

### WIRING
1. `MASTER-CONTEXT.md` → `docs/`. Point agents at it, not the pasted brief.
2. Wallet: mount alongside M25's `stripeApi` with the same `Db`. Then pass
   `makeSpendShards(wallet, userId)` into `StudioMode` and `MarketplaceHub`
   in place of the current seam, and use `wallet.ownedItems()` for
   `AvatarBuilder.setOwnership()`. **The server must re-validate ownership
   on every save — client state is display only.**
3. PerfMonitor: `new PerfMonitor(scene, engine).mount(import.meta.env.DEV)`
   in ModeHarness; call `setPlaying(true)` when the loop starts and
   `warmAll()` on the loading screen.
4. readyMarker: four `setReady()` calls in ModeHarness (see the file footer).
   Then `smoke.mjs` (M66) can wait on `#dunk-ready` instead of a fixed sleep.
5. `deploy.mjs` → `tools/`. Run without `--publish` to package a verified drop.

## ACCEPTANCE
1. A client cannot mint currency: every balance change goes through the
   ledger, and `audit()` returns `ok: true` after a batch of operations.
2. Calling `apply(user, 'LC', +100, 'purchase', key)` **throws** — LC is
   earned-only and the code enforces it.
3. Replaying the same idempotency key credits once, not twice.
4. The perf overlay shows fps/frame/draws/VRAM in dev and reports zero
   shader compiles during a full dunk after `warmAll()`.
5. `#dunk-ready` appears when the dunk scene is up and flips to `playing`.
6. `node tools/deploy.mjs --batch <dir>` refuses to package when a gate
   fails, and produces a timestamped bundle + manifest when they pass.
