# M21 — GROUP WORKOUTS · PRIVATE SEMINARS · PRIVATE BOOKING

Copy this document into Abacus together with every file in `files/`.

---

## PROMPT FOR ABACUS

Extend FEL LIVE (M18) with **paid group sessions and private booking**, using the
files in this package. Three connected experiences:

1. **Online group workouts** — members join Elijah Bonds' live group workout
   sessions through the live stream. **Standing schedule right now: WEDNESDAY and
   FRIDAY at 5:30 PM** (America/Los_Angeles until changed in config). Ticketed
   entry; ticket holders join the stream room when it goes live.
2. **Private educational group seminars** — purchasable seats for private group
   seminars/sessions (biomechanics education, corrective strategies, practical
   applications). These are PRIVATE streams: only seat holders can join; they never
   appear as free content. Capacity-limited.
3. **Private session booking (fallback)** — if NO private seminar is scheduled,
   the same surface offers **"Book a private online session"**: the athlete
   requests a 1-on-1 slot from configured availability; founder confirms; a private
   stream room is created for that booking.

All payments (tickets, seats, private sessions) go through the server-authoritative
wallet in shards. Joining is server-gated (ticket/seat/booking verified before an
HLS URL or room token is issued). Reuse the M18 `StreamPlayer`; private rooms are
just pass-gated streams with a roster. Prove completion with recordings: buy a
group-workout ticket → join Wednesday 5:30 stream; buy a seminar seat → join the
private seminar; empty seminar calendar → book a private session → founder confirms
→ private room join works.

## FILES
| File | Purpose |
|---|---|
| `files/shared/sessionContracts.ts` | Session types, tickets/seats, booking states, pricing, Wed/Fri 5:30 schedule config |
| `files/server/groupSessionApi.ts` | Schedule materialization, purchases, join-gating, booking request/confirm, rosters |
| `files/client/GroupSessionsScreen.tsx` | Sessions surface: group workouts + seminars + fallback booking entry |
| `files/client/PrivateBookingScreen.tsx` | Slot picker → request → status; founder-side confirm list |

## INTEGRATION POINTS
1. **FEL LIVE tab:** add a "SESSIONS" section between the hero and the schedule
   rail; the Live badge also fires for group sessions going live.
2. **Wallet:** `purchaseTicket`, `purchaseSeat`, `bookPrivate` debit shards via
   EconomyService. Refund path: founder-cancelled sessions auto-refund
   (`economy.refund(ledgerId)`).
3. **Streaming:** each session materializes a `StreamMeta` (M18) with
   `access: 'pass'`; `canJoin` (this package) replaces the generic pass check for
   session streams. Join issues the HLS URL ONLY after roster verification.
4. **Notifications:** ticket holders get a reminder push/badge 30 min before start
   (use the existing notification path; if none exists, in-app badge only and note
   it in the report).
5. **Founder admin:** minimal admin list (founder role) to confirm/decline private
   booking requests and cancel sessions. Role check server-side.
6. **Coach tie-in:** AI Coach (M19) can answer "when is the next group workout?"
   from this schedule — add it to the grounding context digest.

## SCHEDULE CONFIG (edit in one place — sessionContracts.ts)
- Group workouts: Wed + Fri 17:30, 60 min, capacity 100, 150◆ per session
  (or included with M18 `class_monthly` all-access).
- Seminars: scheduled ad hoc by founder admin; seat price per event (default 250◆),
  capacity default 25.
- Private 1-on-1: 45 min, 900◆, availability template Mon/Thu 16:00–19:00 —
  fallback offer ONLY when no seminar is scheduled in the next 14 days.

## COMPLIANCE
- Same training disclaimer as classes; private sessions add "not a medical
  consultation."
- Rosters are personal data: attendee lists visible to founder only; join tokens
  are single-user, expiring.
- Minors cannot book 1-on-1 private sessions (age gate); group sessions allowed
  with chat off (M18 rule).

## ACCEPTANCE
1. Wed/Fri 5:30 PM group workouts materialize on the schedule automatically each
   week; ticket purchase (ledger entry) → join gated → HLS issued only to ticket
   holders; capacity enforced.
2. Seminar with seats: purchase → private join works; non-holders blocked
   server-side (verify with a second account).
3. With no seminar in the next 14 days, the booking fallback renders; request →
   founder confirm → private room join for exactly that athlete; decline refunds.
4. Founder cancel refunds all holders automatically (ledger shows refunds).
5. Monthly all-access (M18) includes group workouts but NOT seminars or 1-on-1s.
