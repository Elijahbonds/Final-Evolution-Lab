# M49 — COURT CARNIVAL (new mode: Mario-Party-style minigame hub)

Copy this into Abacus with every file in `files/`. Prerequisite: M42, M43,
M44 deployed (reuses `clipRegistry`, `SoundKit`, `EffectsKit`, `boardCore`,
`aimSwingCore`, `rideWorlds`, `VenueKit` unchanged).

---

## PROMPT FOR ABACUS

### THE IDEA (your framing: "like Mario Party or Pac-Man Fever")
FEL already has the raw material for this — The Vault, Iron Paradise, Beach
Sprint, Tiebreak Blitz, Brain Brawl, and Who Scene It are all short,
self-contained minigames (confirmed in the M46 audit), which is exactly the
unit Mario Party sequences through a rotating hub. Nothing currently
sequences them. This batch builds that hub — **Court Carnival** — using four
NEW, purpose-built quick bursts rather than reaching into the 2D minigames'
source (which this repo has never seen, per M46). Each burst reuses
infrastructure this project already owns and trusts:

| Event | ~Length | Reuses |
|---|---|---|
| SLAM RUSH | 20s | Basketball hoop (VenueKit), charge/release dunk pattern |
| STRIKE STORM | 15s | Dojo (VenueKit), karate strike clips, a stationary training-bag character |
| TRICK GAUNTLET | 20s | The board-sports skatepark + trick machine (`rideWorlds`/`boardCore`), unmodified |
| HOT SHOT | 15s | The precision-sports goal + aim/power core (`aimSwingCore`), unmodified |

### FILES
| File | What it is |
|---|---|
| `files/modes/carnivalEvents.ts` | **New.** The four event definitions behind a small shared `CarnivalEvent` interface (`build`/`onInput`/`tick`/`teardown`), each a thin, simple wrapper around existing, already-shipped systems. |
| `files/modes/CourtCarnivalMode.ts` | **New.** The orchestrator: reveal card → run the event for its clock → tally Carnival Points against a simulated rival (same honest pattern Dunk Contest/1v1 Hoops already use for a rival) → next event → finale with a champion. `modeId: 'carnival'` — a new hub card, doesn't replace anything. |

### WIRING
1. Drop both files in.
2. Add a hub card for Court Carnival pointing at `modeId: 'carnival'`
   (route `/play/carnival`, following the existing pattern every other card
   uses).
3. `modeVerbs.ts`: the `default` entry (stick + ACTION=A) covers the shared
   verb; each event's extra buttons (B/Y/X) reuse the same bindings those
   letters already have in Dunk Contest/Karate Endless/Skate Run/Penalty
   Shootout, so no new TouchOverlay wiring is needed.
4. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE
1. Start Court Carnival — a reveal card announces the first event, then it
   loads and plays for its clock (Slam Rush 20s, Strike Storm 15s, Trick
   Gauntlet 20s, Hot Shot 15s).
2. After each event, a result banner shows your score vs. the rival's and
   the running Carnival Points total, then the next reveal card fires
   automatically — no phase can stall past its watchdog budget.
3. After all four events, a champion is crowned (you vs. rival cumulative
   total) and the session ends with a real result.
4. Each event's world/characters are fully torn down before the next
   builds — no leftover meshes/lights/sound beds from a previous event
   bleeding into the next.
