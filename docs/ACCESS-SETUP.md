# Giving Claude read/write access to the web app

**TL;DR — you don't need to grant me anything new.** I already have read and
write on `elijahbonds/final-evolution-lab`. The problem is that the app I've
been writing code for isn't *in* it.

This is a **sync** task, not an access-provisioning task. That distinction
matters: it means no new credentials, no Abacus platform access, and no
secrets change hands.

---

## What's actually true today

| | |
|---|---|
| My access to this GitHub repo | ✅ read + write (branch `claude/nexus-engine-setup-2qgkik`) |
| The Babylon/Next.js app source in this repo | ❌ **not present** |
| What I've been doing instead | writing against a contract inferred from my own earlier batches |

Every `babylon`/`ModeHarness`/`CharacterLibrary` file in this repo is inside
`docs/abacus-batches/` — my own drop folders. The live app lives only in
Abacus.

### What that costs, concretely

Real defects that all trace to the same cause:

- **M74** shipped duplicate `tennis` and `volleyball` modes; working ones were
  already live. One `grep` would have prevented it.
- **`applyArtCard`** looked for meshes named `court_floor`/`ground` for months.
  No venue has ever built either name. Every art card silently did nothing.
- **M77** — I reported nine modes unrouted; six were live. I was guessing route
  names because nothing reconciled them.
- Every batch since M74 ships with *"not type-checked against the Abacus
  source"* in its limits section. That's a standing disclaimer on all of it.

---

## Option A — sync the app into this repo ✅ recommended

Abacus pushes the web app into a folder here. I get read + write immediately
through access I already have.

**Why this one:** no new credentials, no secrets, fully reversible, and it
puts the app under version control — which it currently isn't in any way you
control.

### Paste this to Abacus

> Please sync the FEL web application source into the GitHub repository
> `elijahbonds/final-evolution-lab`, into a top-level folder named
> `nextjs_space/`, on a new branch `abacus/app-sync`.
>
> **Include:** all application source — `app/`, `lib/`, `components/`,
> `public/`, plus `package.json`, `package-lock.json` (or the lockfile you
> use), `tsconfig.json`, `next.config.*`, `tailwind.config.*`,
> `postcss.config.*`, and `prisma/schema.prisma` if present.
>
> **Exclude — do not commit any of these:** `node_modules/`, `.next/`,
> `out/`, `.vercel/`, any `.env`, `.env.local` or `.env.production`, Firebase
> service-account JSON, and any file containing API keys, database URLs, or
> payment credentials. If a config file is needed for the build but contains
> secrets, commit a `.env.example` with the KEYS ONLY and empty values.
>
> The repo's `.gitignore` has been updated to enforce all of the above, so a
> normal `git add -A` should already do the right thing.
>
> Then open a PR from `abacus/app-sync` into `claude/nexus-engine-setup-2qgkik`.
> After that, please keep syncing: whenever you integrate a batch, push the
> resulting source to that branch so the repo stays current.

### Then tell me it's done

I'll verify the sync myself — that the app installs, type-checks, and contains
no secrets — before touching anything.

---

## Option B — you export and drop it

If Abacus can't push to git: ask it for a zip of the app source (same
include/exclude list above), then drop it here the way you drop my batches. I'll
unpack it into `nextjs_space/` and commit.

Slower and manual, but it works and it's just as safe.

---

## Option C — Abacus platform credentials ❌ not recommended

Don't. It would give me deploy authority I don't need, it's the one path where
real secrets change hands, and it doesn't solve the actual problem — which is
that I can't *read the code*, not that I can't deploy.

I don't want deploy access. Abacus deploying is fine.

---

## What must NOT come across

Non-negotiable. If any of these land in a commit, rotate them immediately:

- `.env`, `.env.local`, `.env.production` — **real values**
- `MONGO_URL`, `DB_NAME`, `DATABASE_URL`
- `EMERGENT_LLM_KEY`, any LLM/API key
- `PAYPAL_CLIENT_ID` / `SECRET`, Stripe keys
- Firebase service-account JSON, `GoogleService-Info.plist`
- Session tokens, `smoke-state.json`

`.gitignore` now blocks all of these by pattern, and I check every commit
before pushing. A `.env.example` with empty values is welcome and useful — it
tells me what the app expects without telling me any of it.

---

## What changes the day this lands

| Today | With the source |
|---|---|
| Batches ship "not type-checked" | I run the real `tsc` before shipping |
| I infer APIs from old batches | I read the actual signatures |
| I proposed duplicate tennis modes | I `grep` before proposing |
| I ship route *instructions* | I wire the routes myself |
| You drag zips into Abacus | I open PRs; Abacus reviews and deploys |
| "Does it render?" | "Does it build, type-check, pass tests, and render?" |

The zip workflow can continue unchanged if you prefer it — this adds a
capability, it doesn't remove one.

---

## Verifying it worked

Once synced, I'll run these and report honestly:

```bash
ls nextjs_space/                                    # source present
git log --oneline -1 -- nextjs_space/               # it committed
cd nextjs_space && npm ci && npx tsc --noEmit       # installs + type-checks
node tools/route_audit.mjs                          # registry vs real routes
grep -rIl -E "(sk_live|mongodb\+srv|BEGIN PRIVATE KEY)" nextjs_space/ || echo clean
```

The last one is the important one, and I'll run it **before** anything else.
If it finds anything, I'll stop and tell you rather than push.

---

## One honest caveat

This removes the blindness, not the risk. I'll still be changing a live
product, and more access means a mistake reaches further. Two things I'll hold
to:

1. **I work on a branch and open PRs.** I won't push to whatever branch Abacus
   deploys from unless you tell me to, per-change.
2. **Abacus stays the deployer.** I want to read and propose, not ship. The
   review step between me and production is worth keeping even when it's slower.
