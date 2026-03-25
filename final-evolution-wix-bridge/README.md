# Final Evolution — Wix ↔ GitHub ↔ Supabase (Sovereign Bridge)

This folder is the **canonical Velo backend** you can copy into a Wix Studio site (or sync via Git).  
Repository name on GitHub: **`final-evolution-wix-bridge`** (create empty on GitHub first, or let Wix create it — see below).

---

## Pillar 1 — GitHub integration roadmap (M4 Pro Mac mini)

### A. Prerequisites

- **Git** (`xcode-select --install` or Xcode Command Line Tools)
- **Node.js** 20.11+ (e.g. `brew install node@20`)
- **GitHub account** + SSH key or HTTPS with Personal Access Token (PAT)
- **Wix Studio** site with **Dev Mode** / Velo enabled

### B. Create the GitHub repository

On [github.com/new](https://github.com/new):

1. Repository name: **`final-evolution-wix-bridge`**
2. Visibility: **Private** (recommended for Secrets / Velo patterns)
3. **Do not** add README/license if you will connect from Wix first (optional — you can push this folder later)

**CLI (local, optional):**

```bash
cd ~/Developer   # or your preferred path
mkdir final-evolution-wix-bridge && cd final-evolution-wix-bridge
git init -b main
git remote add origin git@github.com:YOUR_USER/final-evolution-wix-bridge.git
# copy files from this repo folder `final-evolution-wix-bridge/` into this directory, then:
git add .
git commit -m "Initial Sovereign Bridge: Velo relay + http-functions"
git push -u origin main
```

Use **HTTPS** if you prefer: `https://github.com/YOUR_USER/final-evolution-wix-bridge.git` and authenticate with a **fine-grained PAT** (repo contents read/write).

### C. Connect Wix Studio to GitHub (authorize Mac + Velo)

Exact UI labels move between Wix releases; use Wix’s current doc: **[Set up GitHub integration](https://dev.wix.com/docs/go-headless/wix-vibe/git-hub-integration/set-up-git-hub-integration)** and **[Git integration with Wix CLI](https://dev.wix.com/docs/develop-websites-sdk/code-your-site/developer-environments/ides/git-integration/set-up-git-integration-with-wix-cli)**.

**Typical flow:**

1. **Wix Studio** → your site → **Dev Mode** / **GitHub** (or **Settings → GitHub**).
2. **Connect GitHub** → sign in → **authorize the Wix / Velo GitHub App** for your org/user.
3. Select **repository** `final-evolution-wix-bridge` (or create new from wizard — some flows only allow **new** repo creation from Wix; if so, create via Wix and then `git clone` locally).
4. Complete **branch** mapping (usually `main`).

**Mac mini authorization:** Use **SSH** (`~/.ssh/id_ed25519.pub` added to GitHub → **Settings → SSH and GPG keys**) or **HTTPS + credential helper** so `git pull` / `git push` from Terminal does not prompt every time.

**Wix CLI (local sync):**

```bash
npm i -g @wix/cli   # or follow Wix docs for current package name
wix login
cd ~/Developer/final-evolution-wix-bridge
wix dev             # local preview when supported
wix env pull        # pull secrets placeholders to .env.local — never commit real secrets
```

> **Note:** “Instant” updates still require **Publish** from Wix or a successful **CI → GitHub → Wix** pipeline depending on your plan. Git push updates **GitHub** immediately; the **live site** updates when Wix pulls/deploys that revision.

---

## Pillar 2 — Clone on your Mac

```bash
cd ~/Developer
git clone git@github.com:YOUR_USER/final-evolution-wix-bridge.git
cd final-evolution-wix-bridge
```

If this repo was bootstrapped from **rork-final-evolution-lab**, you can instead **subtree** or **copy** only the `final-evolution-wix-bridge/` directory into your GitHub repo.

---

## Pillar 3 — Velo files in this package

| File | Role |
|------|------|
| `backend/velo-relay.jsw` | **Web module** — `relayToSupabase`, `creditsForWixCents`, payload builders; uses **Wix Secrets** (`getSecret`). |
| `backend/http-functions.js` | **HTTP Functions** — `post_felRelayWixOrder`, `post_felWixOrderPaidFromAutomation` (required file name for Velo). |
| `backend/velo-bridge.js` | Thin re-exports for Cursor / imports (optional). |
| `.cursorrules` | Bonds Standard + latency discipline for Cursor. |
| `CLINICAL_AUDIT.md` | 16.6 ms **frame-budget** audit vs Wix/Edge reality. |

### Wix Secrets (Dashboard → Secrets Manager)

| Secret | Value |
|--------|--------|
| `FEL_SUPABASE_ORDER_URL` | `https://<project>.supabase.co/functions/v1/wix-order-completed` |
| `FEL_WIX_WEBHOOK_SHARED_SECRET` | Same string as Supabase `WIX_WEBHOOK_SHARED_SECRET` |

### Automation URL (Order paid → Webhook)

`https://<your-domain>/_functions/felWixOrderPaidFromAutomation`

---

## Supabase (server side)

```bash
supabase secrets set WIX_WEBHOOK_SHARED_SECRET="your-long-random-string"
supabase functions deploy wix-order-completed --no-verify-jwt
```

See parent repo: `supabase/functions/wix-order-completed/index.ts`.

---

## Troubleshooting

- **401 from Supabase:** Header `X-FEL-Wix-Secret` must match exactly (no quotes, no trailing newline in Secrets).
- **400 zero_credits:** `creditsForWixCents` has no mapping for that `totalAmountCents` — extend the map in `velo-relay.jsw`.
- **Git LFS / large assets:** This bridge is code-only; 3D assets stay in the main **rork-final-evolution-lab** repo.
