# NEXUS STUDIO — CELL × NEXUS: the AI Super-Agent Builder

**One sentence:** a simplified, optimized 3D game/app creator — Unreal-class output,
none of Unreal's weight — where **the LLM is the architect and orchestrator**, CELL is
its ever-learning brain, agents build in parallel (Kimi-style delegation), and the
platform can package, host, and ship what it creates — to the web instantly, to the
App Store through a human-approved gate.

Lineage: Abacus AI (execution partner) × Seele AI (design lineage — `seeles_work/`)
× the NEXUS C++ engine × CELL. In the spirit of AI Studio / Antigravity-class
agentic environments, but **owning its own engine** instead of driving someone else's.

---

## Why this is buildable HERE: the pillars already exist as code

| Vision pillar | Existing code (this branch, today) |
|---|---|
| LLM-as-architect seam | `engine/ai_interface/` — agent server, command router + schema, Gemini/AI-Studio prompt clients. The engine is ALREADY driveable by an LLM through a typed command surface (`fel.*`, `cell.*`). |
| Parallel agent delegation | `engine/cell/agent_swarm` + `agent_executor` + `agent_tool` (git/terminal/IDE tools, MCP surface) + `engine/core/job_system`. |
| Self-learning brain | CELL: ObservationBus → ExperienceLedger → ResearchLoop → WisdomStore → ModelTrainer, G-Eval quality gate, DocIngester (RAG), **YouTubeLearner** (self-development from video), curriculum advisor. |
| 3D content factory | `engine/generative/` — scan import → chunk merge/index → procedural mesh → model gen → manifest registrar. Plus the proven external pipe: Meshy (assets) + DeepMotion (motion) + Blender headless. |
| "Games as artifacts" runtime | `engine/core/nexus_cartridge_runtime` — created games are **cartridges** the engine loads. This is the packaging unit for created content. |
| Hosting & backend | `backend/app` FastAPI + Postgres + Dockerfile; gateway (`/nexus/v1/*`) in flight; marketplace schema for distribution/monetization. |
| Web studio surface | The Abacus web app (three.js/R3F) — becomes the Studio UI: prompt → scene graph → live preview. |
| Ship to devices | Proven in this workspace: headless Unity/Xcode pipelines, `devicectl` installs, App Store Connect-ready signing. The automation pattern exists end-to-end. |

**Nothing above is speculative — every row is on `nexus/platform-core` or proven in
this project's history.** The Studio is an integration, not an invention.

---

## Architecture

```
                    ┌────────────────── NEXUS STUDIO ──────────────────┐
 User intent ──────►│ ARCHITECT (frontier LLM #1 — long-horizon design) │
 ("make me a        │   • decomposes into a BuildPlan (typed JSON)      │
  volleyball        │   • owns coherence, style, scope                  │
  roguelike")       └──────┬───────────────────────────────┬───────────┘
                           │ plan                          │ verify
              ┌────────────▼-──────────┐        ┌──────────▼──────────┐
              │ BUILDER SWARM           │        │ CRITIC              │
              │ (agent_swarm: N parallel│        │ (G-Eval gate + CELL │
              │  workers, model-mixed:  │        │  wisdom + test runs)│
              │  frontier #2 for hard   │        │  reject → re-plan   │
              │  lanes, fast models for │        └──────────┬──────────┘
              │  mechanical lanes)      │                   │
              └──────┬─────────┬────────┘                   │
                     │         │                            │
        ┌────────────▼──┐   ┌──▼──────────────┐             │
        │ CONTENT       │   │ CODE            │             │
        │ generative/ + │   │ gameplay modes, │             │
        │ Meshy/DeepMo/ │   │ cartridge logic │             │
        │ Blender pipes │   │ (fel.* surface) │             │
        └────────────┬──┘   └──┬──────────────┘             │
                     └────┬────┘                            │
                   ┌──────▼──────────────────────────┐      │
                   │ CARTRIDGE (the artifact)         │◄─────┘
                   │ scenes + assets + rules manifest │
                   └──────┬───────────┬───────────────┘
                          │           │
              ┌───────────▼───┐   ┌───▼─────────────────────────┐
              │ PUBLISH: WEB  │   │ PUBLISH: iOS                 │
              │ auto: container│  │ auto: build+sign+upload      │
              │ image + deploy │  │ HUMAN GATE: submit for review│
              │ + hosted URL   │  │ (owner's Apple account)      │
              └───────────────┘   └─────────────────────────────┘
                          ▲
                          │ every build outcome → ObservationBus
                   ┌──────┴──────┐
                   │ CELL learns  │  what worked → WisdomStore →
                   │ from building│  better plans next time
                   └─────────────┘
```

### Multi-model orchestration (Claude Fable 5 × GPT-5.x × Gemini …)
One **provider-agnostic LLM router** (extend `ai_interface`'s existing client
pattern): `ModelProvider` interface → Anthropic / OpenAI / Google adapters, with
**roles not brands**: `architect` (deep planning), `builder` (parallel lane work),
`critic` (evaluation), `summarizer` (cheap). Roles map to models by config, so
Fable 5 × GPT-5.6 today can be swapped or A/B'd tomorrow. CELL's G-Eval +
WisdomStore score every model's output per role — **the router learns which model
earns which job.** Kimi-style behavior = architect emits N independent lane specs →
agent_swarm executes concurrently → critic merges (exactly the workflow pattern that
built this repo).

### "Creates its own operating systems" — the honest version
Not literal OS kernels. Three real layers, in feasibility order:
1. **Runtime environments (now):** every created game/app is a cartridge + a
   generated container image (Dockerfile authored by the builder, built + run by the
   platform) — its own isolated, reproducible "world."
2. **The Studio OS (next):** the orchestrator itself as the operating system OF the
   agents — scheduler (self_improvement_scheduler), filesystem (artifact store),
   processes (swarm workers), IPC (ObservationBus), package manager (marketplace).
3. **Unikernel-style images (research):** compiling cartridge + minimal runtime into
   a bootable image. Real but far; do not gate anything on it.

### App Store publishing — the honest version
Automatable end-to-end EXCEPT the final gate: archive → sign → upload via App Store
Connect API is scriptable (patterns proven in this workspace). **Submission for
review and account actions remain owner-approved, always** — that's both Apple's
rules and this project's standing safety rule.

---

## Roadmap (each phase ships something usable)

- **P0 — Platform floor (in flight now):** sequencer/authoring/marketplace/gateway
  lanes + CELL hardening on `nexus/platform-core`; 117 files landed, gate pending.
- **P1 — Architect loop, one genre:** LLM router (3 providers) + BuildPlan schema +
  `studio.create` command → cartridge out → playable in the web app. Prove:
  *prompt → playable volleyball variant in minutes.* (Everything needed exists;
  this is wiring + one new router.)
- **P2 — Builder swarm + critic:** parallel lanes through agent_swarm; G-Eval-gated
  merges; CELL observes build outcomes and starts biasing plans.
- **P3 — Publish rail:** container image per creation + hosted URL (web, fully
  auto); iOS build+sign+upload with the human submit gate.
- **P4 — Studio surface + marketplace:** Abacus web app grows the creator UI
  (prompt, scene tree, live preview, publish button); creations become marketplace
  cards (schema already live).

## Division of labor
- **Claude (here):** bulk platform development on `nexus/platform-core` — engine
  seams, orchestrator, router, cartridge/publish rails. Gate-verify-commit.
- **Abacus:** the web Studio surface + hosting rail, iterating on the gateway
  contract, exactly as it does the app today.
- **Copilot:** welcome, but every commit must pass the full gate (see
  NEXUS_HANDOFF_FOR_ABACUS.md ⚠ — three orphan-source breaks so far).
- **Elijah:** taste, priorities, Apple/account gates, and the only hand on
  publish-to-store.
