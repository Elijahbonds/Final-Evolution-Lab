# THE FINAL REGRESSION PASS — closing checklist for the 10-phase plan (M51–M62)

Phase 10's second deliverable: the single checklist that certifies the whole
plan once every batch is dropped into Abacus. Work top to bottom AFTER
deploying in order; I'll run the full live playtest audit against the
deployed build on the next cycle and verify every line myself.

## 1. Deployment order (dependencies flow downward)
M51 → M52 → M53 → M54 → M55 → M56 (incl. the M28 route wiring action) →
M57 → M58 → M59 → M61 → M60 → M62.
(M59/M61 are visual and can land any time after M44; M60/M62 are UI/server
and independent of the mode batches.)

## 2. The standing KNOWN-ERRORS sweep (run once, whole app)
All 8 steps of the KNOWN-ERRORS.md sweep: console sweep (zero MISSING
CLIP / FEL-FRAME / FEL-SPAWN / 404s), single control deck, 60s recorded
runs (karate + dunk + one ride + one precision), HUD doubling check,
camera-in-geometry check, ride-mode floor check, smoke test, secret scan.

## 3. The open items only a human/real device can close
- **E25 real-device check (M51)** — Dunk Contest charge→launch on real
  hardware: does the character visibly animate? Console must show either
  nothing (healthy) or `[FEL-ANIM] SKINNING STALL` + self-heal.
- **M28 routes** — `/play/music` (now the Academy) must resolve; art/dance
  routes wired or their real paths reported.
- **Credentials to provision when ready**: Stripe recurring Price
  `fel_all_access_monthly` (+ webhook events) · `FEL_SPOTIFY_CLIENT_ID` ·
  `FEL_APPLE_DEV_TOKEN` · real `profile`/`spendShards`/wallet props into
  Studio/Marketplace/FoodScan/KitchenHub.

## 4. Per-batch acceptance spot-checks (one line each — full lists in each README)
- M51: no T-pose regressions; loud stall diagnostics if any.
- M52: touch SHOOT works in 1v1/3v3; ankle-breaker + shot types fire; dunk
  rim-cam cut + chains.
- M53: Karate VS best-of-3 with parry/guard-break/Dragon; Mixed Combat
  ring-outs both directions; hub card for `mixedcombat`.
- M54: football TRUCK + style chains; tennis rallies vs a returning
  opponent; golf preview + 3-click; soccer feints move the keeper.
- M55: skate bowl/downhill/rail bonuses; snowboard rocks/rails/lift-cable
  grind + the Yeti once per run; surf barrels + buoys.
- M56: Carnival random 4-of-6 with both new events; Dunk Duel full
  pass-and-play match; hub card for `dunkduel`.
- M57: Academy boots audible (zero audio file requests); master/kits/
  cell-foundation/publish/library/remix all work.
- M58: pasted Spotify/Apple links play via official embeds; connect cards
  never fake success; streaming chips on published tracks.
- M59: rim-lit, inked, saturated look in every 3D mode; framerate holds.
- M61: painted sky + horizon in every camera direction, every mode.
- M60: pass checkout/webhook/stipend in Stripe test mode; marketplace
  buy/fees/KDP export; author desk outline+scaffolds; food scan goal-
  relative scoring + daily caps.
- M62: kitchen listed → shift subscribed → plan published (kitchen-gated)
  → meal sub; compliance notice always visible.

## 5. What remains honestly open after this plan
Real networked multiplayer (transport), Cell/Nexus LLM wiring at the
marked seams, streaming SDK credentials, KDP is manual-by-design, story
mode build (approved design → one batch), IRL-video dunk duel (rides M36
ghosts), Dance/Art deep passes pending their route wiring.
