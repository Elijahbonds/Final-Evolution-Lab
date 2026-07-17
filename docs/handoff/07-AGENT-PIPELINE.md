# 07 — AGENT PIPELINE · Abacus ↔ Kimi ↔ Claude

The workflow that maximizes what each agent is best at. Elijah is the director; every
loop ends with them playtesting the live build.

```
        ┌────────────────────────────────────────────────────────┐
        │                       ELIJAH                           │
        │        vision · priorities · live playtests            │
        └───────┬────────────────────────────────┬───────────────┘
                │ direction                      │ feedback
                ▼                                │
   ┌─────────────────────┐   spec batches   ┌────┴──────────────┐
   │  CLAUDE (this repo) │ ───────────────► │  ABACUS BUILDER   │
   │  playtests the live │                  │  owns the live    │
   │  build · writes     │ ◄─────────────── │  app · applies    │
   │  specs/tickets ·    │   new build up   │  batches · hosts  │
   │  revises Kimi work  │                  └───────▲───────────┘
   └───────┬─────────────┘                          │ revised batch
           │ briefs + backlog                       │ (by Claude)
           ▼                                        │
   ┌─────────────────────┐    Kimi batch     ┌──────┴────────────┐
   │  KIMI               │ ────────────────► │  CLAUDE review    │
   │  generates complete │                   │  gate (below)     │
   │  implementation     │                   └───────────────────┘
   │  files per 04 brief │
   └─────────────────────┘
```

## Roles
- **Abacus builder** — owns/hosts the live app source. Receives drag-and-drop document
  batches (specs or revised code batches) and applies them. Output: a new live build.
- **Kimi** — file-generation engineer. Consumes `04-KIMI-BRIEF.md` + backlog; emits
  `kimi-batches/K{n}-{slug}/` (MANIFEST + complete files + tests). Never talks to
  Abacus directly.
- **Claude (Claude Code, this repo)** — spec author, playtester, and REVIEW GATE.
  Verifies the live build with a real browser; writes/maintains all handoff docs and
  m13-style ticket batches; revises Kimi batches into Abacus-ready form; keeps the
  GitHub repo (`claude/nexus-engine-setup-2qgkik`) as the system of record.
- **Elijah** — picks priorities, changes scope, playtests every deployed build (the
  FEL BUILD PLAYTEST template in m13 docs / prior notes), and drags batches into Abacus.

## The loop (one iteration)
1. **Direction:** Elijah sets/confirms the next backlog item(s) (`05`).
2. **Brief:** Claude ensures specs are current (updates 02 after each playtest;
   updates 03/05/06 on scope changes) and cuts a scoped assignment for Kimi.
3. **Generate:** Kimi produces batch `K{n}` per `04` (manifest, whole files, tests,
   acceptance mapping).
4. **Review gate (Claude):**
   - Checks: applies-clean (no dangling refs), contract conformance (06), acceptance
     mapping complete, M13 root causes not regressed, thumbs-only preserved.
   - Fixes what's cheap to fix; kicks back to Kimi ONLY for structural gaps (wrong
     scope, missing acceptance coverage) with a numbered defect list.
   - Output: `abacus-batches/{milestone}/K{n}-revised/` — the batch re-expressed as
     Abacus-consumable documents: a READ-FIRST wiring doc + the files, with
     integration instructions resolved (Assumptions → concrete mounts).
5. **Apply:** Elijah drags the revised batch into Abacus; builder applies; new build.
6. **Verify:** Claude browser-playtests the new build against the batch's acceptance
   mapping + m13-08 checklist for touched modes; files a findings doc
   (pass/fail per criterion). Failures become the next batch's top items.
7. Repeat.

## Repo layout for the pipeline
```
docs/handoff/                 ← this package (specs, briefs, contracts)
docs/abacus-batches/m13/      ← ticket batches for Abacus (specs)
docs/abacus-batches/{ms}/K*/  ← Claude-revised Kimi code batches for Abacus
kimi-batches/K{n}-{slug}/     ← raw Kimi output (committed as received)
docs/playtests/{date}-{build}.md  ← Claude verification reports
```
Everything is committed and pushed to `claude/nexus-engine-setup-2qgkik` so Elijah can
review any artifact from a phone via GitHub.

## Ground rules
- One milestone at a time; a batch claims backlog IDs and closes them or says why not.
- Raw Kimi output is preserved unmodified (auditability); revisions live beside it.
- Every playtest updates `02-CURRENT-STATE.md` — it must always describe the LIVE build.
- Secrets/IP rules from `00` bind every agent in the pipeline.
- If two docs conflict: 01 (vision) > 03/06 (specs/contracts) > 05 (backlog) > older
  batches. Claude resolves and edits the losing doc in the same commit.

## Why this maximizes current agents
- Abacus is strongest at applying scoped, concrete document batches to its own app —
  so everything it receives is pre-integrated and acceptance-mapped.
- Kimi is strongest at high-volume complete-file generation — so it gets a frozen
  spec, stable contracts, and a strict manifest format instead of open-ended asks.
- Claude is strongest at verification, integration reasoning, and spec writing — so
  it owns the gates on both sides (brief → Kimi, revise → Abacus, verify → live).
```
