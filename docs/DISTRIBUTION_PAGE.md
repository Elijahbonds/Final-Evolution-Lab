# FEL Distribution Page — `/download`

**Branch:** `seele/distribution-page` (off `anti-gravity-fel`)
**Route:** `/download`
**Component:** `frontend/src/components/DistributionPage.js`
**Visual language:** matches `LandingV2` — obsidian (#050505) + neon cyan (#00E5FF) + indigo-violet (#5E17EB). Pure SVG + CSS. Zero new npm deps.

---

## 1. Sections (top → bottom)

| # | Section | Purpose | Test ID |
|---|---|---|---|
| 1 | Sticky Nav | Logo · 4 anchor links · "Enter Lab" CTA | `dist-nav`, `dist-nav-login` |
| 2 | Hero | "Get the Athlete OS" headline · platform-list ribbon | `dist-hero-platforms`, `dist-hero-login` |
| 3 | Platform Grid | 4 cards (iOS · macOS · Android · Web) with SVG store badges | `platform-grid`, `platform-{ios,macos,android,web}` |
| 4 | Install & Register Guides | Tabbed 5-step install instructions per platform | `install-guides`, `guide-tab-{ios,macos,android,web}`, `guide-steps-{...}` |
| 5 | Web Game Client Shell | Animated container scaffold for the future web wrapper | `web-client-shell`, `shell-boot-stage` |
| 6 | FAQ | 6 collapsible Q&As | `dist-faq`, `faq-q-{i}`, `faq-a-{i}` |
| 7 | Footer CTA | "Download. Audit. Train." | `dist-footer-cta` |
| 8 | Footer | © · Privacy · Terms | — |

---

## 2. Hand-off — what to swap when real assets land

### 2a. Store badge URLs
The platform card `storeUrl` is currently `"#"`. Update in `PLATFORMS` array at the top of `DistributionPage.js`:

```js
{ id: "ios",     storeUrl: "https://apps.apple.com/app/idXXXXXXXXX" },         // App Store listing
{ id: "macos",   storeUrl: "https://apps.apple.com/app/idXXXXXXXXX?mt=12" },   // Mac App Store
{ id: "android", storeUrl: "https://play.google.com/store/apps/details?id=com.antigravity.finalevolutionlab" },
{ id: "web",     storeUrl: null }, // keep null until web client is live
```

### 2b. Official badge artwork
Currently every store badge is composed from a small inline SVG inside the `StoreBadge` component. When official Apple / Google artwork is ready:

1. Drop the badge PNGs into `frontend/public/badges/`:
   - `app-store-en.png`     (Apple guideline 160×54)
   - `mac-app-store-en.png` (Apple guideline 156×52)
   - `google-play-en.png`   (Google guideline 156×60)
2. Replace the `<StoreBadge kind="..." />` component body with `<img src={...} alt="..." />` calls.

Search markers in code: `DISTRIBUTION_BADGE_REPLACE`, `DISTRIBUTION_LINK_REPLACE`.

### 2c. Web client launch
When the web client ships, update `PLATFORMS[3]`:
```js
{ id: "web",
  status: "available",
  statusLabel: "Live",
  storeUrl: "https://play.finalevolutiongroup.com",
  ... }
```
The shell visualization in §3 will then anchor to the real route via deep link.

---

## 3. Web Game Client Shell — container framework

The shell renders an animated boot sequence cycling through 5 stages:
`INITIALIZING SHELL → NEGOTIATING SIGNALING → ALLOCATING GPU CONTEXT → STREAMING ASSET MANIFEST → READY`

Plus 3 capability cards underneath:
- **WebGPU pipeline** — render-path target
- **WebTransport signaling** — QUIC session control to Sovereign Hub
- **Sovereign auth bridge** — same Bearer-token flow as native apps

When the real web client is integrated, replace the `WebClientShell` body with the `<iframe>` or `<canvas>` mount. Keep the same `data-testid="web-client-shell"` outer container for tests.

Recommended integration shape:
```jsx
<div data-testid="web-client-shell" className="relative aspect-video w-full ...">
  <iframe
    src="https://play.finalevolutiongroup.com/embed?token=..."
    allow="xr-spatial-tracking; gamepad; clipboard-read; clipboard-write; web-share"
    className="absolute inset-0 w-full h-full"
  />
</div>
```

---

## 4. Install guide content — single source of truth

The 5-step install copy lives in the `GUIDES` const at the top of the component. Each entry is `{ label, icon, steps: [{t,b},...], requirements: [...] }`. Edit there — no other code changes needed.

When iOS / macOS / Android version baselines bump (e.g. iOS 18 minimum), update only the `requirements` array.

---

## 5. Accessibility notes

- All store badges are wrapped in `<a>` tags with `data-testid` and visible label text for screen readers.
- FAQ uses native `<button>` with `aria-expanded` semantics via `ChevronDown` rotation only — for a future a11y pass, add `aria-controls` and `aria-expanded` attributes explicitly.
- Color contrast on the grid backdrop has been tuned: body text (`text-white/60`) sits at WCAG AA on `#050505` for 14px+.

---

## 6. Registry / catalog impact

**None.** The download page is purely a marketing/onboarding surface. It does NOT register a new mode, change `FEL_ModeManager.production.json`, or call any backend route. It uses the existing Emergent Google OAuth handshake (same as `LandingV2`).

The shell visualization is a pure-CSS animation — it does NOT open a WebSocket, does NOT touch the Sovereign Hub, does NOT call any signaling server. It's a placeholder until the real web client ships.

---

## 7. Validation (Phase 5 compliance per `SEELE_AI_EXECUTION_PACKAGE.md` §6.6)

- [x] Files added: `frontend/src/components/DistributionPage.js` (~530 LOC) + this doc
- [x] Files modified: `frontend/src/App.js` (3 lines — import, route, page-shim helper)
- [x] Registries touched: **none**
- [x] Test ids present: 16+ (`distribution-page`, `dist-nav`, `dist-nav-login`, `dist-hero-*`, `platform-grid`, `platform-{ios,macos,android,web}{,-download,-guide}`, `install-guides`, `guide-tab-*`, `guide-steps-*`, `web-client-shell`, `shell-boot-stage`, `dist-faq`, `faq-q-*`, `faq-a-*`, `dist-footer-cta`, `badge-{appstore,macappstore,googleplay,web}`)
- [x] Lint: `eslint frontend/src/components/DistributionPage.js frontend/src/App.js` → 0 errors
- [x] No backend changes
- [x] No new npm dependencies
- [x] No UE5/Source touches

### Anti-Gravity review checklist
- [ ] Validate `/download` route renders 200 in preview
- [ ] Visual QA the 4 platform cards on 375px / 768px / 1920px viewports
- [ ] Confirm store badges are placeholders that can be swapped without code churn
- [ ] When real App Store / Play Store URLs land, update `PLATFORMS[*].storeUrl` (one-liner edits)
