# Contractor onboarding — Final Evolution Lab (Sovereign Lab)

Use this when bringing on a developer to ship the product. **Never commit** API keys, `service_role` keys, Apple certificates, or `web/fel-public-config.js` (copy from `fel-public-config.example.js`).

## What this repo is

- **Primary gameplay / tools target:** Unreal Engine 5.7 — `UnrealStarter/BasketballGame/` (see `UNREAL_ONLY.md`, `.cursorrules`).
- **iOS shell / legacy Swift:** `FinalEvolutionLab/` (still in tree; product direction is Unreal-first unless a task says otherwise).
- **Marketing / clinical gateway (Vite):** `sites/final-evolution-main-site/` — Netlify; Mac DMG lives on **Supabase Storage**, not in git.
- **Static `web/`:** alternate Netlify root; PWA under `/play/`.

## Clone and build

```bash
git clone https://github.com/Elijahbonds/rork-final-evolution-lab.git
cd rork-final-evolution-lab
```

- **Unreal:** Open `UnrealStarter/BasketballGame/FinalEvolutionLab.uproject` in UE 5.7+; index the game **Source** folder in your editor.
- **Marketing site:** `cd sites/final-evolution-main-site && npm ci && npm run build`
- **Gold Master Mac pipeline:** `UnrealStarter/BasketballGame/Content/FEL/Venues/GOLD_MASTER_MAC_PACKAGING.txt` and `scripts/run_gold_master_release.sh`

## For the owner: stay synced with GitHub

Your machine may be **ahead of `origin/main`** until you push. From repo root:

```bash
git status
git push origin main
```

If HTTPS asks for a password, use a **GitHub Personal Access Token**, or switch to SSH:

```bash
git remote set-url origin git@github.com:Elijahbonds/rork-final-evolution-lab.git
git push origin main
```

Install [GitHub CLI](https://cli.github.com/) (`brew install gh`) then `gh auth login` for simpler auth.

## Option A — Keep this repository (recommended)

The project already lives at **`https://github.com/Elijahbonds/rork-final-evolution-lab`**. Grant the contractor **read** (or **write** if they should open PRs) access under **Settings → Collaborators** (or move the repo into a GitHub **organization** and use teams).

No new repository is required—only a clean **push** so `main` on GitHub matches your laptop.

## Option B — Create a **new** GitHub repository

Use this if you want a fresh name, org ownership, or a private fork without history.

1. GitHub → **New repository** → choose name (e.g. `sovereign-lab`), visibility, **do not** add README/gitignore (you already have a tree).
2. Point your local repo at the new remote and push:

```bash
cd /path/to/rork-final-evolution-lab
git remote rename origin old-origin   # optional backup
git remote add origin git@github.com:YOUR_ORG/YOUR_NEW_REPO.git
git push -u origin main
```

To **replace** history or split later, use `git filter-repo` or export a patch—only if you have a specific compliance need; otherwise prefer Option A.

## What to give the contractor

| Item | Notes |
|------|--------|
| Repo access | GitHub invite |
| Unreal version | **5.7** (paths assume `/Users/Shared/Epic Games/UE_5.7` on Mac; they set `UE_ROOT` if different) |
| Supabase | **Anon** key + URL for client work; **service_role** only on secure CI or your machine—never in repo |
| Apple / notarization | Their machine or yours; profile via `xcrun notarytool store-credentials` |
| Design / product | `FINAL_EVOLUTION_LAB_CONTEXT.md`, `PROJECT_FLOWS.md`, `NEURO_MECHANIC_BRIDGE.md` as needed |

## Security checklist before sharing

- [ ] No `.env`, `fel-public-config.js`, or `service_role` in commits (`git log -p` spot-check).
- [ ] `.gitignore` ignores `web/fel-public-config.js`, `.supabase/`, build outputs.
- [ ] Contractor uses **branch + PR** workflow if you want review before `main`.

## Questions

Open issues or a short **Slack/Discord** channel for Unreal + Netlify + Supabase integration questions; keep secrets in a password manager or GitHub **Environments** secrets for CI.
