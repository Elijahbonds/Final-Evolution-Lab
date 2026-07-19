# M20 — THE CLOSET · Avatar Editor, Wearables & Card Skins

Copy this document into Abacus together with every file in `files/`.

---

## PROMPT FOR ABACUS

Build **The Closet** — the avatar identity surface of Final Evolution — using the
files in this package. In the Closet, every player can:

1. **Edit their avatar's face** — skin tone, face shape, hair (style + color),
   eyes (shape + color), eyebrows, mouth, nose. Fixing a face the scan/default got
   wrong must take under a minute.
2. **Dress their avatar** — wearables by slot (headwear, tops/jersey, shorts/pants,
   shoes, accessories) from owned items; buy new ones with coins.
3. **Apply Creator Card skins** — a Creator Card the player owns can carry a full
   avatar skin (outfit + palette + optional signature item); equipping the card's
   skin re-themes the avatar in one tap. Ownership is verified server-side.
4. **See everything live** — a large 3D preview (reuses the M17
   `MiniAvatarPreview` rig seam) updates on every change; the avatar plays idle or
   a strut clip while being dressed.

The saved **Look** applies EVERYWHERE the avatar renders: all game modes, the hub,
workout mini-movies (M17), result screens, and Cell's references to the player.
One look store, no per-surface forks.

## FILES
| File | Purpose |
|---|---|
| `files/shared/closetContracts.ts` | FaceConfig, Wearable slots/items, AvatarLook, card-skin types, DTOs |
| `files/shared/wearableCatalog.ts` | Seed wearable catalog + rarity/pricing + card-skin definitions |
| `files/server/closetApi.ts` | Get closet, save look, buy wearable (coins), equip card skin (ownership check) |
| `files/client/ClosetScreen.tsx` | The Closet UI: live preview, category tabs, save/equip flows |
| `files/client/FaceEditor.tsx` | Face tab: swatches + sliders per feature, randomize, reset |

## INTEGRATION POINTS
1. **Rig seam (extends M17 `LoadedRig`):** implement
   `setFace(face: FaceConfig)` — morph-target weights (face/nose/mouth/eye shape
   sliders map to blendshape weights 0..1) + material swaps (skin/hair/eye color)
   + hair mesh attachment per `hairStyle`. And `equip(slot, itemId | null)` —
   attach/detach wearable meshes at slot sockets. If the current character model
   lacks blendshapes, ship the preset-based fallback included in the contracts
   (discrete face presets instead of sliders) and note it in the report.
2. **Economy:** wearable purchases debit COINS (soft currency) via the server
   wallet; card skins are never bought here — they come with owned Creator Cards
   (premium slots remain the shard sink from M17/Phase 7). No pay-to-win: all
   items cosmetic.
3. **Look propagation:** `AvatarLook` is stored per user and merged into
   `MiniAvatarSpec` consumption sites — game character spawn, workout movies,
   hub preview. One `resolveLook(userId)` call everywhere.
4. **M17 tie-in:** after a scan builds proportions, route the player THROUGH the
   Closet ("Fix your look") before the avatar reveal completes — proportions from
   the scan, identity from the Closet.
5. **Entry points:** Profile → "Closet"; home screen avatar chip long-press;
   post-scan flow. ≤2 taps from home (redesign rule).

## COMPLIANCE / DESIGN RULES
- Inclusive ranges are mandatory: full skin-tone spectrum (12 swatches + fine
  slider), hair styles covering afro-textured/braids/locs/straight/wavy/cropped/
  hijab option, eye shapes across ethnicities. This is a hard acceptance item.
- No purchasable stat advantages; rarity affects looks only.
- Face data is cosmetic config, NOT biometric identification data — but it still
  falls under the same delete-my-data control (Profile) as scan data.

## ACCEPTANCE
1. Recording: open Closet → change skin tone, hair style+color, eyes, mouth, nose →
   preview updates live per change → save → launch a game mode AND a workout
   mini-movie: the avatar renders the saved look in both.
2. Buy a wearable with coins (ledger entry), equip it, see it in-game.
3. Equip an owned Creator Card skin → full look applies; attempting an unowned
   card's skin fails server-side.
4. Inclusivity check passes (all listed ranges present and functional).
5. Delete-my-data also clears the saved look.
