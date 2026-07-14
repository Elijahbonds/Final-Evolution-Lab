# NEXUS / CELL — Cost Doctrine (2026-07-14)

**Mission:** turn FEL game telemetry into personalized athletic education, and give
Elijah leverage to build FEL itself. **Constraint:** solo dev, no credit-metered
platform dependency. **Doctrine:** own the data and the evals; rent intelligence
per-call; make the runtime free.

This doc governs all CELL/NEXUS work by Abacus, Copilot, and any other agent.
It complements `NEXUS_HANDOFF_FOR_ABACUS.md` (branch/gate rules live there).

## The core shift

In today's climate, hand-rolled learning algorithms are the commoditized part —
frontier reasoning costs pennies at small tiers, open weights are competitive,
batch APIs run ~50% off. What is NOT commoditized: **FEL's telemetry** (PRQ events,
session results, mastery curves, movement data) and **FEL's evals** (what "good
coaching" means here). CELL's job is not to learn — it is to decide **when to buy
learning** and to keep the receipts (data + evals) that make every purchased call
cheaper and better than the last.

## The four-layer cost architecture

| Layer | Who does the work | Marginal cost |
|---|---|---|
| Runtime (sequencing, scoring) | Deterministic math, pre-computed content | ~$0 |
| Daily learning (insights, mastery updates) | Batch API, cheap model | cents/day |
| Creation (curriculum, code, coaching corpora) | Frontier model + G-Eval gate | paid once |
| Escalation (hard calls only) | Frontier model, budget-capped | rare |

Held together by two disciplines:
- **Prompt caching everywhere** — stable system prompts + repo/curriculum context
  as a cached prefix on every call.
- **Golden-set evals per tier** (20–50 fixed tasks) — so models can be swapped to
  whatever is cheapest each quarter, with quality verified within an hour. Models
  change faster than architecture should; evals make model-hopping safe.

## CELL rules

1. **No always-on loops.** IdleFeed, continuous research loops, and idle agent
   swarms convert to **nightly batch jobs**: ship the day's telemetry via batch
   API to a cheap model, write insights back to the wisdom store. Same
   intelligence, half price, zero runtime cost.
2. **No LLM in the sequencer's inference path.** "What lesson next" is
   deterministic Elo/BKT-style mastery math — free, fast, explainable,
   better-validated than per-request LLM guessing. LLMs work **offline** authoring
   the curriculum graph, difficulty ratings, and remediation rules.
3. **Distill, don't subscribe.** Where runtime judgment is genuinely needed
   (feedback text, coaching tone): frontier model generates a labeled corpus
   offline once; serving runs on a small model (Haiku-tier API or self-hosted open
   weights for the dev loop). Pay the smart model to teach, not forever to answer.
4. **Every autonomous loop has a budget cap and a stop condition.** "Zero-cost
   agent swarm" means unmetered, not free. One shared budget module: max
   tokens/day per subsystem, hard stop, log what was skipped. Unmeasured spend is
   the failure mode that kills solo projects.

## NEXUS rules

- **Gateway-first stays.** `/nexus/v1/*` is the only integration surface — every
  intelligence provider must be swappable behind it without touching the game.
  Provider independence is insurance in a market where prices move monthly.
- **Authoring is the highest-ROI LLM spend.** Content is created once, served
  forever — frontier quality amortizes perfectly. Spend big on authoring + G-Eval
  review gates; spend nothing on serving (pre-computed, cached).
- **NEXUS Studio** follows the same doctrine applied to code: BYO API keys, tiered
  model routing (cheap builder → escalate on failure), content-hash caching,
  diff-based iteration — never full regeneration of unchanged work.

## Model routing (see model-routing test protocol)

Three tiers, each filled by whatever wins the golden-set eval at the lowest cost:
architect (hardest calls), bulk generation (cheapest per token), harness/execution
lane (fastest). Current candidates: Grok 4.5 / Tencent Hunyuan HY3 / NVIDIA
Nemotron 3 Ultra, with a stronger model as auto-escalation fallback until
escalation rate <10% over ≥20 tasks and cost/task is stable ±20%.

**Compliance denylist (hard router rule):** Tencent-Cloud-hosted models never
receive Neuromechanic scoring logic or specs, biometric/likeness/mocap data
(BiometricMirror, user video, animation rigs), or EU AI Act disclosure drafts
(Aug 2 work). Self-host open weights for denylisted work.

## Priority order (next 30 days)

1. Wire the sequencer loop end-to-end with deterministic math
   (game → `/nexus/v1/session-result` → mastery update → `/nexus/v1/queue`).
   No LLM in the path. This completes the mission's core promise at ~$0 marginal.
2. Budget meter + caps on every CELL loop (one shared module, per-subsystem logs).
3. Convert IdleFeed/research loops to the nightly batch job.
4. Build the golden-set evals; run the three-model routing test on real tasks.
5. Only then: authoring pipeline at frontier quality behind the G-Eval gate.

**One-sentence version:** make runtime free, make learning nightly, make creation
excellent, and make every model swappable behind the gateway.
