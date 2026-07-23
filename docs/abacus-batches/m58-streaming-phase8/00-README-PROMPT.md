# M58 — PHASE 8: streaming display & control (official embeds live now, credentialed control seamed)

Copy this into Abacus with every file in `files/`. Prerequisite: M57
deployed (this batch's `StudioLibrary.ts` and `StudioMode.tsx` REPLACE
M57's; `StreamingBridge.ts` and `StreamingDeck.tsx` are NEW).

---

## PROMPT FOR ABACUS

### The honest architecture (this is the whole point of the batch)
Your three music-integration asks split cleanly into what ships TODAY vs.
what needs credentials only you can obtain:

**LIVE THE DAY THIS DEPLOYS (zero credentials):** Spotify and Apple Music
both publish OFFICIAL embed players (`open.spotify.com/embed/…`,
`embed.music.apple.com/…`) that render and play inside an iframe with no
API keys — full tracks for listeners already signed into those services in
the same browser, previews otherwise. ToS-clean: it's their player, their
stream, the artist gets the play. Everything in this batch runs on that.

**NEEDS YOUR CREDENTIALS (marked seams, never faked):** full in-app
playback CONTROL — play/pause/skip/seek/queue on FEL's own buttons with no
iframe — requires:
- *Spotify*: a free Developer-app CLIENT_ID (developer.spotify.com) +
  OAuth + the listener having Premium (Web Playback SDK requirement).
  Seam: `FEL_SPOTIFY_CLIENT_ID`.
- *Apple Music*: an Apple Developer Program membership ($99/yr) + a
  MusicKit developer token minted server-side. Seam: `FEL_APPLE_DEV_TOKEN`.
`StreamingConnect.requestConnect()` records intent and reports exactly
what's missing — it never shows a fake "connected" state. When you have
the credentials, the swap points are documented in-code.

### What ships
1. **THE LISTEN FLOOR** (`StreamingDeck.tsx`) — paste any Spotify/Apple
   share link → the official player renders and plays inside the Academy.
   A persistent shelf of saved links (localStorage + SYNC SEAM), and
   per-provider CONNECT cards that state truthfully what full control needs.
2. **Streaming links on published tracks** — the "authorized playback on
   save" ask, honestly interpreted: when a creator PUBLISHES a track in the
   studio, they can attach their own Spotify/Apple link for the same song;
   the library card then shows a provider chip that expands the official
   embed inline. `StudioLibrary.attachStreamingLink()` also lets links be
   added after the fact.
3. **The NVIDIA question, answered for the record**: "motion bricks" is not
   a real, current NVIDIA product or API — there is nothing to integrate.
   Nothing in FEL's animation pipeline needs or could use it.

### FILES
| File | What it does |
|---|---|
| `files/music/StreamingBridge.ts` | **New.** URL→official-embed parser (track/album/playlist/artist for both providers), connect-state with credential seams, saved-links shelf. |
| `files/music/StreamingDeck.tsx` | **New.** The LISTEN floor UI: paste-and-play embeds, shelf, truthful connect cards. |
| `files/music/StudioLibrary.ts` | v2 — `streamingLinks` on TrackRecord + `attachStreamingLink()`. REPLACES M57's. |
| `files/music/StudioMode.tsx` | v2 — LISTEN tab, optional streaming-link field on publish, provider chips + inline embeds on library cards. REPLACES M57's. |

### WIRING
1. Drop all four files in (two replace M57's by filename).
2. CSP/headers: allow iframes from `open.spotify.com` and
   `embed.music.apple.com` (frame-src) — the only external surface, and
   it's the providers' own official widget.
3. When you obtain the credentials above, wire them at the two marked
   seams in `StreamingBridge.ts`; the UI needs no changes.
4. No modeVerbs/TouchOverlay changes.

## ACCEPTANCE
1. Paste a Spotify track link on the LISTEN floor → the official Spotify
   player renders and plays right there; same for an Apple Music link.
   Album/playlist links render the taller browse player.
2. The shelf persists across reloads; remove works.
3. CONNECT on either provider never claims success — it reports exactly
   what's needed and logs the `[FEL-STREAM]` seam note.
4. Publish a studio track with a Spotify link attached → its library card
   shows a green ▶ SPOTIFY chip that expands the official player inline;
   the FEL mixdown ▶ PLAY still works beside it.
5. Zero scraped/proxied audio anywhere — every external stream goes
   through the providers' own embedded players.
