# Clinical Gate — React (v1.0.0)

Optional **Vite + React + Tailwind** shell that mirrors the **mandatory medical disclaimer** (`felHasAcceptedMedicalDisclaimer` in `localStorage`, same key as Swift `@AppStorage` string value pattern).

**Primary iOS implementation:** `Source/Views/MedicalDisclaimerView.swift` + `Source/ContentView.swift`.

## SFMA JSON ↔ Unreal

Swift `FelReadinessSnapshotExport` encodes **`sfmaMultiSegmentalRotationPassed`** (camelCase).  
Unreal `FELReadinessIO::ParseSnapshotJsonString` reads **`sfmaMultiSegmentalRotationPassed`** and also accepts alias **`sfma_multi_segmental_rotation_passed`**.

When **`false`**, Spiral Line congestion / red roadblock visuals follow `UFELBiometricOverlays` logic.

## Build

```bash
cd web/clinical-gate-react
npm install
npm run build
```

Output: `dist/` — deploy as a Netlify subfolder, separate site, or embed via iframe (set CSP as needed).

## Netlify

This is **not** the main static `web/` root (gateway + `/play/` PWA). Either:

- Deploy `dist/` as its own site, or  
- Copy `dist/*` into `web/clinical/` and add routes in `netlify.toml`.
