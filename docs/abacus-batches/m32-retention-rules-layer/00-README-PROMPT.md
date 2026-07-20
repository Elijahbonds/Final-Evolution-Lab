# M32 — RETENTION RULES LAYER (5 features, zero new assets)

Copy this document into Abacus with every file in `files/`. Every feature here
is a RULES layer on systems that already exist — no new models, animations, or
engine work — so this batch can ship while visual passes continue in parallel.

---

## PROMPT FOR ABACUS

Implement these five features using the files provided. All reward math is
server-side (standing rule: modes report raw stats, servers mint rewards).

### 1 · MASTERY TRACKS (cross-mode long arc)
Per-mode cumulative mastery: bronze → silver → gold → platinum → legend, earned
from session scores. Sigil renders on the player's card, hub avatar chip, and
mode cards ("your rank" on each cartridge). One system gives all 22 modes a
long-term goal. `masteryApi.ts` + thresholds in `progressionContracts.ts`.
Wire: call `recordMastery()` inside the existing session-result handler; render
sigils from `GET /api/mastery`.

### 2 · DAILY CONTRACTS (the daily-return mechanic)
Three rotating cross-mode objectives/day ("evade 10 defenders", "land 2
eastbays", "collect 40 coins on the slope"), paying coins + season XP. Progress
is evaluated SERVER-side from each SessionResult's stats — clients cannot mint.
`contractsApi.ts` includes the deterministic daily rotation (seeded by date, no
cron needed), progress matching against stat keys, and claim flow. Wire: run
`applySessionToContracts()` in the result handler; hub shows the three
contracts with progress bars + CLAIM.

### 3 · KING OF THE COURT (3v3 win-streak mode)
Rules wrapper on the 3v3/court core: win → hold the court, opponents escalate
(speed/accuracy/archetypes per defense of the crown), streak = the score;
one loss ends the run. `KingOfTheCourt.ts` provides the escalation table,
streak state, crown HUD hooks, and the SessionResult shape (`KOTC_STREAK_N`).
Also grants the `kotc_crown` mastery bonus at 5+ streak.

### 4 · RIVALRY LADDER (1v1 campaign)
Five named AI rivals with distinct personalities, stat profiles, signature
moves, and win/loss lines (Coach/Cell tone rules apply: no body/identity
insults). Beat one → unlock their signature move for YOUR moveset + the next
rival. `RivalryLadder.ts` holds the rival roster (data), unlock persistence
endpoints, and the mode hooks (apply rival profile to the 1v1 AI; apply
unlocked move to the player's kit).

### 5 · SKATE VS. GHOST (async multiplayer, reuses replay tech)
Classic S.K.A.T.E. against a friend's recorded run: player A records a trick
line (input+transform stream — tiny payloads, deterministic replay, same
format as Triumph Arena ghosts); player B must match each trick or take a
letter; five letters = loss. `SkateLetters.ts` (match logic + letter state) +
`ghostApi.ts` (store/fetch ghost runs, challenge links — plugs into the
existing CHALLENGE A FRIEND deep-link flow).

## ACCEPTANCE
1. Mastery: two sessions in two modes move two different tracks; sigil visible
   on hub avatar + both mode cards; thresholds match the table exactly.
2. Contracts: today's three render identically across devices (seeded);
   finishing a qualifying session advances the right contract; CLAIM pays once
   (replay the claim → 409); contracts rotate at midnight UTC without a deploy.
3. KOTC: streak 3 shows escalated opponents (log the applied multipliers);
   loss ends run with `KOTC_STREAK_N` result; crown bonus lands at 5.
4. Rivalry: beating rival 2 unlocks rival 3 + the signature move appears in the
   player's 1v1 kit; losses produce the rival's win line, never a generic one.
5. SKATE: record a 3-trick line on one account, challenge a second account via
   link, letters accrue on misses, match completes and reports results for both.
