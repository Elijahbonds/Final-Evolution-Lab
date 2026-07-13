# COPILOT.md — Standing Instructions

> Load this file at the start of every Copilot session. These rules are permanent and override any in-session drift.

---

## Standing Instructions

- Three separate tracks exist: **FEL** (the product), **Nexus** (an authoring layer), and the **AI harness** (a tool). They have a **hard firewall**: FEL ships first; the harness only exists to speed FEL; Nexus is extracted *after* FEL's core works. **Never merge two tracks into one task.** If a Nexus or harness feature would block FEL, flag it and stop.
- Runtime is **Babylon.js** (web-native). ML endpoints live in **Abacus** — Abacus owns all ML, Babylon owns the runtime, never cross them. Launch target is Abacus when ready.
- Repo: `github.com/Elijahbonds/Final-Evolution-Lab`.
- Architecture baseline: **four movement cores + eight shared systems** as the foundation; game modes are swappable skins on top. Three-tier connectivity: offline gameplay → sync-when-available progression → online-required for live multiplayer + real-money modes.
- When asked for a feature, **confirm which track it belongs to before writing code.**

### Tie-breaker rule

> *When unsure what to work on, work on whatever gets FEL to a playable, shippable slice. The other two tracks wait.*

---

## Track 1 — FEL (build now)

- Scope v1 to **two hero modes only: dunking + karate.** Do not scaffold the other 21 modes; stub their interfaces behind the swappable-skin system so they can be added later without refactor.
- Implement the **four movement cores + eight shared systems** first as the real foundation; the two hero modes are the first skins.
- Build the **PRQ (performance profile) loop**, **Skill Lab curriculum hook** (Bonds Bounce Blueprint), and **HealthKit/wearable integration**.
- Respect these compliance gates and surface them in code comments/TODOs:
  - **Real-money IRL Dunking** = legal-review-gated — do not ship live without sign-off.
  - **Meshy Free tier** is CC BY 4.0 = **not commercial-safe** — use commercial-licensed assets only.
  - **EU AI Act** disclosure obligations begin **Aug 2, 2026**.
  - **UGC surfaces** need a moderation pipeline before going live.
- Deployment: build for **Abacus/web deploy**; keep **offline-first** so gameplay works without connectivity.

---

## Track 2 — Nexus (do NOT build from scratch)

- Nexus is an **authoring/orchestration layer on top of Babylon.js — not a new engine.** Do not write a renderer, physics, scene graph, or asset importer; Babylon already provides these. Nexus's only value is prompt-to-scene, prompt-to-model, prompt-to-build with an integrated ChatLLM.
- **Do not start Nexus until FEL's core exists.** When we do start, build one primitive first: **prompt → Babylon scene.** Nothing else.
- Console support later via **Babylon Native**, never a rewrite.
- Keep it simple by construction: expose authoring intents, not engine internals.

---

## Track 3 — AI Harness (tool, not a model)

- Build an **orchestration harness that wraps existing models** (route cheap models to cheap tasks, expensive only where needed — this is how "avoid token cost" is actually satisfied: routing + caching, not owning weights). **Do not attempt to train or build a frontier model.**
- Connect git, terminal, IDE; support **parallel synced agents** on a **checkpoint-loop** model (not full autonomy).
- Reuse the three-agent design:
  - **Strategist** — brainstorm/prompt-draft loop
  - **Vision Guardian** — output vs. creative-vision check
  - **Build Monitor** — must hook into **real build logs**, not speculative LLM reasoning
- Only build harness features that make FEL ship faster right now. Everything else is parked.
