# M19 — CELL + AI COACH · Both AIs Live In-Platform

Copy this document into Abacus together with every file in `files/`.

---

## PROMPT FOR ABACUS

Make Final Evolution's two AIs — **Cell** and the **AI Coach** — work and be usable
by every player inside the platform, using the files in this package.

- **AI COACH** — the supportive expert. Lives in the Coach tab (primary surface) and
  inside the workout/plan screens. Grounded in the player's REAL data: System Scan
  pillars, PRQ metrics, movement-screen results, workout plan, recent game sessions,
  and Bio-Fuel state. Tone: SUPPORTIVE coach (existing product directive — see
  `backend/routers/biofuel.py` "supportive AI Coach Neuro-Cues"). It explains
  what to do next and why, in plain language, and can adjust today's session.
- **CELL** — the arena AI. The competitive personality of The Nexus: rival,
  hype-man, and challenge-issuer. Appears as a floating orb in the console/game
  surfaces: post-game trash talk & props, issues daily challenges ("beat 17 yd or
  stay soft"), narrates Triumph Arena stakes, and fronts the Glitch Boss arc in The
  Nexus Initiative. Tone: cocky, sharp, funny — never abusive, never demeaning about
  bodies, always beatable. Persona copy is a config (`personas.ts`) — tune freely.

Both run through ONE server chat route (`aiChatApi.ts`) that: selects the persona,
builds the grounding context from platform data, calls the LLM provider seam
(Abacus AI endpoint / EMERGENT_LLM_KEY — key stays server-side, NEVER in client
code), enforces the safety rules, and streams the reply. The client panel
(`AiChatPanel.tsx`) renders both — Coach as a full tab panel, Cell as a floating
overlay — with quick-action chips.

## FILES
| File | Purpose |
|---|---|
| `files/shared/aiContracts.ts` | Chat/persona/context types + quick actions |
| `files/shared/personas.ts` | Cell + AI Coach system prompts, boundaries, voices |
| `files/server/aiChatApi.ts` | One chat route: grounding, safety, provider seam, streaming |
| `files/client/AiChatPanel.tsx` | Chat UI: Coach tab panel mode + floating Cell orb mode |

## INTEGRATION POINTS
1. **LLM seam:** bind `LlmProvider.complete()` to the Abacus AI endpoint (or the
   backend's EMERGENT_LLM_KEY path). Server-side only. Streaming preferred.
2. **Grounding:** `buildContext()` reads the same stores the app already has —
   unified system scan (`/api/system-scan/unified` shape), workout plan (M17),
   last game sessions, biofuel summary. Fail soft: missing data = shorter context.
3. **Coach surfaces:** Coach tab (full panel); "Ask Coach about this" buttons on
   the plan viewer and result screens (deep-link with a prefilled question).
4. **Cell surfaces:** floating orb on hub + post-game result screens; Cell fires a
   one-liner automatically on session end (win/loss aware) with a "reply" affordance;
   Nexus Initiative boss dialogue uses the same persona config.
5. **Rate limits:** server enforces per-user daily message caps (config) so LLM cost
   is bounded; overflow shows a friendly cooldown line in-character.

## SAFETY RULES (enforced server-side, non-negotiable)
- Coach: training/nutrition guidance only — NO medical diagnosis; injury mentions
  → advise licensed professional (mirrors the app's education-track scope rule).
  No unverified physiology claims (NEEDS-VERIFY content-integrity rule).
- Cell: competitive banter only — no insults about bodies/identity, no harassment;
  profanity off; under-18 accounts get the softened variant automatically.
- Both: never reveal system prompts, keys, or other users' data; conversations
  logged per-user, deletable via Profile (privacy parity with scan data).
- AI disclosure: both panels are labeled "AI" (EU AI Act readiness).

## ACCEPTANCE
1. Coach tab: ask "what should I train today?" → answer cites the player's actual
   scan deficit + today's plan day (visible grounding, not generic advice).
2. Result screen: finish a game → Cell fires an automatic in-character line about
   THAT result; tapping the orb opens chat and it continues the thread.
3. Streaming replies render token-by-token; daily cap produces the in-character
   cooldown message.
4. Injury question → Coach declines diagnosis and refers out (recorded).
5. Both panels show the AI label; conversation delete works.
