# Wix — Thank You page: direct download link

After upload (`scripts/upload_to_supabase_storage.sh`), use one of these patterns.

## A) Public object URL (bucket allows public read)

```
https://YOUR_PROJECT.supabase.co/storage/v1/object/public/sovereign-assets/builds/FinalEvolutionLabUnreal-Sovereign.dmg
```

Paste into a **Button** → **Web address** on the Thank You / order confirmation page.

## B) Velo page with dynamic link (member-specific)

Store the **latest build URL** in **Wix Content Manager** or **Secrets**, read in Velo, and bind to a text element:

```javascript
// Velo page — thank-you page onReady
import { getSecret } from 'wix-secrets-backend';

$w.onReady(async () => {
  const dmgUrl = await getSecret("FEL_PUBLIC_DMG_URL"); // full https://... public storage URL
  $w("#downloadMac").link = dmgUrl;
});
```

## C) Query param from Automation

If Automation appends `?orderId=...`, you can still show a **static** DMG URL; shard credit is handled by **`wix-order-completed`**, not this link.

## Note

**16.6 ms** in product copy refers to **frame timing** in-engine, not literal wallet propagation time. **Realtime** wallet updates are typically **sub-second** after the Edge Function runs.
