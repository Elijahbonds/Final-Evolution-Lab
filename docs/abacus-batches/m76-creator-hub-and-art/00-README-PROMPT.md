# M76 — Creator Hub reaches a page, and two silent art bugs

Depends on M28 (`CreatorCardTypes`, `CreatorHub`, `ArtMode`, `creatorCardApi`)
and M73/M74 for venue mesh names.

**Prerequisites shipped alongside:** `creator/CreatorCardTypes.ts` (M28, included
here unchanged so the batch type-checks standalone).

---

## WHY `/creator` WAS A 404

M28 shipped a Creator **picker** (`CreatorHub.tsx`) and a Creator **API**
(`creatorCardApi.ts`). Nothing connected them. The picker's `onEnter` had
nowhere to send you, the API had nothing calling it, and there was no page for
a route to point at. Cards could be *sold* in the live marketplace and never
*made*.

## `creator/CardBridge.ts` — the missing spine, **38 tests passing**

Takes what a mode actually produces and turns it into a validated
`CreatorCard`. Every rule is enforced client-side *and* on the server: the
server stays authoritative, this is the fast no.

```
node --experimental-strip-types tests/card_test.ts  →  38 passed, 0 failed
```

What the tests pin down:

- **The licence is opt-in and cannot be defaulted.** `licenseAccepted !== true`
  throws. Defaulting it would attach a licence its creator never agreed to.
- **Payload must match the primary discipline.** A music card carrying an art
  payload lists fine and delivers nothing — invisible until someone buys it.
- **Sport designation is required iff sport is involved**, in either primary or
  secondary, and rejected when it isn't.
- **UGC audio moderation is decided by the payload, not the caller.** `music`
  and `acting` enter `pending_review`; nothing can ask to skip it.
- Each discipline's payload must actually contain its content — a dance card
  with zero steps, a music card with no stems, an art card whose canvas isn't
  a `data:image/` URL are all rejected at construction.

### The flat-marketplace rule, encoded and tested

`royaltiesFor()` pays the immediate parent's creator **and stops**. It never
walks the remix chain paying every ancestor.

That's a structural limit, not an optimisation: a royalty that compounds up a
lineage turns a marketplace into a downline. Two tests hold the line —
*"a remix-of-a-remix pays exactly one creator"* and *"the grandparent is NOT
paid"*. Self-remixing pays nobody either.

## `modes/art/applyArtCard.ts` v2 — two bugs that made art cards do nothing

**1. It looked for meshes that have never existed.** v1 mapped
`court: ['court_floor', 'ground']`. No venue builds either name — VenueKit and
the M73 Nexus venues both use **`venue_ground`** (deliberately, so the M64
camera occlusion probe can see them). So `applyArtCard(scene, url, 'court')`
logged "no mesh" and returned false *every time*. Same class as the M74 naming
bug: a lookup by string that nothing validates until it silently misses.

**2. It replaced a PBR material with a Standard one.** Every M73 venue surface
is `PBRMaterial`; swapping in `StandardMaterial` discards roughness/metallic
and drops the surface out of the scene's lighting model, so a painted court
would read as flat and lit differently from everything around it. v2 paints
the **existing** material's albedo, so art lands *inside* the venue's look.

It now returns a structured `ApplyResult` — v1 returned `false` for both "no
such surface" and "card has no image", which are different problems.

## `pages/CreatorStudio.tsx` — the page

Pick a discipline → author → publish. It deliberately owns **no authoring UI**:
art routes to M28's `ArtMode`, music to the live `/studio`, dance to
`DanceMode`. Re-implementing any of those here would fork a surface that
already works.

## FILES

| File | Goes where |
|---|---|
| `files/creator/CardBridge.ts` | game source `creator/` |
| `files/creator/CreatorCardTypes.ts` | `creator/` — M28's, unchanged |
| `files/modes/art/applyArtCard.ts` | `modes/art/` — **REPLACES M28's** |
| `files/pages/CreatorStudio.tsx` | app pages — route **`/creator`** |
| `files/tests/card_test.ts` | repo `tests/` |

## WIRING

1. Route **`/creator`** → `CreatorStudio`, and **`/play/art`** → M28's `ArtMode`
   (it exists and is complete; it has simply never been routed).
2. `onSaved` → `POST /api/cards` (`creatorCardApi.createCard`).
3. `ArtMode`'s `onPublish` currently emits `unknown`; `CreatorStudio` expects
   `{ dataUrl, palette, brushSetId?, surface? }`. Confirm the shape.

## ACCEPTANCE

1. `node --experimental-strip-types tests/card_test.ts` → **38 passed**.
2. `/creator` loads, and publishing without ticking the licence is refused with
   a field-specific message.
3. `/play/art` loads M28's painter.
4. Applying an art card in any mode logs
   `[FEL-ART] applied art card to "venue_ground" (court)` — not "no mesh".

## NOT DONE

- **Acting has no mode.** `VoiceCapture.ts` exists in M28; there is no
  `ActingMode` and `/play/acting` is a 404. It is the one discipline of five
  with no playable surface.
- `CreatorStudio` is not type-checked against the app (same limit as M74/M75).
  `CardBridge` is proven by execution; the React glue is not.
