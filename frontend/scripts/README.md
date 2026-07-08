# Music Mode dev/verification scripts

- `webaudio-mock.cjs` — deterministic offline WebAudio graph mock (Node, not shipped).
- `determinism-check.mjs` — proves `renderProjectToWav` is byte-identical across
  renders. Run: `node scripts/determinism-check.mjs` from `frontend/`.

These are verification-only; nothing here is imported by the app bundle.
