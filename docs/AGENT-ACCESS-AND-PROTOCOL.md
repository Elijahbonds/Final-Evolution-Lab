# Who can read and write what — and how the three agents stay in sync

**Audience:** Elijah, plus every agent working on FEL — Claude Code (cloud),
Claude Code (Mac Mini), Abacus AI.
**Status:** Authoritative for the **web-first** era. Supersedes
`docs/NEXUS_AGENT_ORCHESTRATION.md` (last updated 2026-06-19, iOS/NEXUS-only,
written before the web pivot) for anything touching the Babylon app.
**Verified:** 2026-07-26, by running the commands, not by assumption.

---

## Part 1 — The access map

### The short answer

| Agent | Reads the repo | Writes the repo | Reads the live app source | Deploys | Local machine |
|---|:---:|:---:|:---:|:---:|:---:|
| **Claude Code (cloud)** — me, on your phone | ✅ all branches | ✅ one branch | ❌ **not in repo** | ❌ | ❌ ephemeral container |
| **Claude Code (Mac Mini)** | ✅ | ✅ | ✅ *if it's on the disk* | ❌ | ✅ full |
| **Abacus AI** | ❌ today | ❌ today | ✅ owns it | ✅ **only one** | n/a |

**Nobody can currently see everything, and the one agent that can ship is the
one agent not connected to version control.** That is the single structural
problem behind most of what follows.

---

### Claude Code (cloud) — the session you're typing into now

Running in an ephemeral Linux container, reached from the Claude app on your
phone.

**Can:**
- Read every branch of `elijahbonds/final-evolution-lab` — `main`,
  `claude/nexus-engine-setup-2qgkik`, `nexus/*`, `integration/*`.
- Write and push to **`claude/nexus-engine-setup-2qgkik` only**.
- Run Node, Python, bash, real test suites.
- **Drive the live deployed site with headless Chromium.** This is how every
  real bug so far was found — the start-gate stall, the camera collapse, the
  27%-of-viewport mobile canvas. It is my most valuable capability and it does
  not require repo access to the app.
- Read screenshots and console logs from that live session.

**Cannot:**
- See the Babylon/Next.js app source. **It is not in this repo.** Everything
  named `ModeHarness`/`InputBus`/`CharacterLibrary` here lives under
  `docs/abacus-batches/` — my own drop folders, i.e. the code I *sent*, not
  the code that's *running*.
- Deploy anything.
- Touch your Mini's filesystem.
- Access the Abacus platform. I declined those credentials deliberately and
  still would: it's the one path where real secrets change hands, and it
  solves the wrong problem. I need to *read the code*, not to ship.
- Persist anything. The container is wiped. **If it isn't pushed, it's gone.**

**What that costs, concretely:** M74 shipped duplicate tennis and volleyball
modes that already existed. `applyArtCard` looked for a mesh name no venue has
ever built. M77 reported six live routes as broken. All the same cause.

### Claude Code (Mac Mini)

**Can — and is the only agent that can:**
- Read and write the entire local filesystem at
  `/Users/elijahbonds/Final-Evolution-Lab`.
- **Run Blender** → `tools/fel_conform.py`. Nothing else can conform a mocap
  file. The M80 pipeline is blocked on exactly this.
- **Run a real `tsc`** against app source, if the app is on that disk.
- Run Xcode, `xcodebuild`, iOS simulators.
- Open real browsers on a real GPU — the cloud container is on SwiftShader, so
  anything about actual rendering performance can only be measured there.
- Push to git.

**Needs from you:** git credentials, and its own branch namespace (`mini/*`).
It must not push to my branch, and I must not push to its.

### Abacus AI

**Can:**
- Read and write the live Next.js/Babylon app source.
- **Deploy.** It is the only agent that can put anything in front of a user.
- Integrate the batch zips you drag in.

**Cannot, today:** see the repo, see my analysis, see the Mini's work, or tell
anyone what it changed. Every integration is invisible to the other two agents
until I playtest the deployed result and infer it.

**This is the bottleneck.** Two of three agents are working blind on the
codebase that matters.

---

### The one change that fixes the map

Get `nextjs_space/` into the repo. `docs/ACCESS-SETUP.md` has the paste-ready
request. Nothing else in this document reaches its full value without it:

| Today | With the source synced |
|---|---|
| Batches ship "not type-checked" | real `tsc` before shipping |
| I infer APIs from my own old batches | I read the actual signatures |
| I propose duplicate modes | I `grep` first |
| I write route *instructions* | I wire routes |
| Abacus's changes are invisible | every integration is a diff all three can read |

**No secrets in that sync.** `.env*`, Firebase service-account JSON,
`MONGO_URL`, `EMERGENT_LLM_KEY`, PayPal/Stripe keys, `smoke-state.json` — all
excluded and all blocked by `.gitignore`. A `.env.example` with empty values
is welcome.

---

## Part 2 — How three agents stay in unison

### The governing constraint

**These agents cannot talk to each other.** There is no shared memory, no
message bus, no way for me to call the Mini. Any protocol that assumes
otherwise is fiction.

What all three *can* touch is **the git repository**. So:

> **The repo is the bus. If it isn't committed, it didn't happen.**

Everything below follows from that one sentence.

### Rule 1 — One writer per path

Merge conflicts are how multi-agent work dies. Prevent them structurally.

| Path | Owner | Others |
|---|---|---|
| `nextjs_space/**` (once synced) | **Abacus** | propose via PR only |
| `docs/abacus-batches/**` | **Claude cloud** | read-only |
| `tools/**`, `tests/**` | **Claude cloud** | Mini may add under `tools/mini/` |
| `assets/ready/**` | **Claude Mini** (only one with Blender) | read-only |
| `FinalEvolutionLab/**`, `engine/**`, `app/**` | **Claude Mini** | read-only |
| `backend/**` | **Claude cloud** | Abacus deploys it |
| `docs/agents/journal/<agent>.md` | that agent **only** | read-only |
| `docs/BLUEPRINT.md` | **Claude cloud** | others append to their journal instead |

### Rule 2 — One branch per agent, `main` is shared truth

```
main                              ← shared truth; nobody force-pushes
claude/nexus-engine-setup-2qgkik  ← Claude cloud
mini/<topic>                      ← Claude Mini
abacus/app-sync                   ← Abacus
```

Merge into `main` through PRs. Rebase onto `main` before starting work, not
after finishing it.

### Rule 3 — Append-only journals, never a shared file

Each agent owns exactly one file and only ever **appends** to it. Two agents
appending to two different files can never conflict, which is the entire
point:

```
docs/agents/journal/claude-cloud.md
docs/agents/journal/claude-mini.md
docs/agents/journal/abacus.md
```

Entry format — five lines, no prose:

```markdown
## 2026-07-26T21:40Z · claude-cloud
DID: M80 external animation pipeline; 67 tests pass
TOUCHED: docs/abacus-batches/m80-external-animation/**
FOUND: InputBus sprint threshold makes keyboard movement always-sprint
NEEDS: Mini — run fel_conform.py on one DeepMotion export (nothing else can)
NEXT: movement + route-teardown diagnosis
```

`NEEDS:` is the only cross-agent channel that exists. It is a request left in
a place the other agent will read, not a message it will receive.

### Rule 4 — Read before you write

**Every agent, first action of every session, no exceptions:**

```bash
git fetch origin && git log --oneline origin/main -15
node tools/agent_sync.mjs            # what changed, who needs what
cat docs/BLUEPRINT.md                # what we're building and why
```

`tools/agent_sync.mjs` prints every open `NEEDS:` addressed to you and every
journal entry since your last one. It is the closest thing to inter-agent
messaging that actually exists.

### Rule 5 — Claim before you build

Before starting anything larger than a one-file fix, append a journal entry
with `CLAIM:` and push it. If you fetch and find someone else already claimed
it, take the next item. Cheap, and it prevents the M74 failure (two agents
building tennis) without any locking machinery.

### Rule 6 — Say what you did not verify

Every handoff states its evidence level. This is not politeness; it's what
stops the next agent from building on sand:

- **VERIFIED** — I ran it, here's the output
- **INFERRED** — reasoned from code I read, not executed
- **ASSUMED** — I could not check; here's the assumption

The M77 route audit was wrong because INFERRED was reported as VERIFIED.

### Rule 7 — Never
- force-push a shared branch
- commit `.env*`, service-account JSON, `smoke-state.json`, or any key
- edit another agent's journal
- claim a mode is "done" without a playtest artifact (screenshot + console log)

---

## Part 3 — What to do first

1. **You:** send `docs/ACCESS-SETUP.md`'s paste block to Abacus. Nothing else
   here reaches full value without it.
2. **You:** give Claude Code on the Mini this repo and this document. Its first
   job is `docs/BLUEPRINT.md` §2 — Blender is on the Mini and nowhere else.
3. **Abacus:** integrate M80, then start appending to
   `docs/agents/journal/abacus.md`. Even three lines per integration ends the
   blindness.
4. **Me:** the movement and route-teardown diagnoses in `docs/BLUEPRINT.md`
   §1.1 and §1.2 — both need a live playtest, which is the thing I can do that
   the others can't.
