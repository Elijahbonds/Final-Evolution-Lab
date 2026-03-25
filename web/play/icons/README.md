# PWA icons (placeholders)

Add branded assets before production:

- `icon-192.png` — 192×192 (Sovereign Gear helmet or lockup)
- `icon-512.png` — 512×512

`manifest.webmanifest` lists **any** + **maskable** purposes for both sizes (iOS/Android home screen).

`index.html` includes two `apple-touch-icon` links (192 and 512); iOS will pick the best match. Optional: add `icon-180.png` and a single `apple-touch-icon` pointing at 180×180 for classic iPhone dock sizing.

Replace PNGs with your 3D render exports from Blender / Keyshot.
