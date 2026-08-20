# Web deploy — Firebase Hosting (Classic)

**Vercel is retired for this repo.** Static surfaces deploy to **Firebase Hosting** on project `final-evolution-lab`.

## Prerequisites

```bash
npm i -g firebase-tools
firebase login
firebase use final-evolution-lab
```

## CRA dashboard (was on Vercel)

Local dev (unchanged):

```bash
cd frontend && npm install --legacy-peer-deps && npm start
```

Build + deploy:

```bash
./scripts/deploy-hosting.sh fel-dashboard
# or
cd frontend && npm ci --legacy-peer-deps && npm run build && firebase deploy --only hosting:fel-dashboard
```

Default URLs: `https://final-evolution-lab.web.app`, `https://final-evolution-lab.firebaseapp.com`

Preview channel (staging):

```bash
cd frontend && npm ci --legacy-peer-deps && npm run build
firebase hosting:channel:deploy preview --only hosting:fel-dashboard
```

## Custom domain — finalevolutiongroup.com

1. Firebase Console → Hosting → **Add custom domain** on the target site (`final-evolution-lab` or a dedicated marketing site).
2. Add DNS records Firebase provides (typically `A`/`AAAA` to Hosting IPs or `CNAME` to `ghs.googlehosted.com`).
3. Wait for SSL provisioning (automatic).

Map marketing to a dedicated Hosting site when `sites/finalevolutiongroup.com/` exists:

```bash
firebase hosting:sites:create finalevolutiongroup
firebase target:apply hosting fel-marketing finalevolutiongroup
# then add fel-marketing block to firebase.json — see Config/firebase_hosting_targets.txt
./scripts/deploy-hosting.sh fel-marketing
```

## Future Vite sites

When `sites/`, `web/clinical-gate-react/`, or `web/` land in-repo, follow **`Config/firebase_hosting_targets.txt`** and **`artifacts/coord/vercel_migration_handoff.json`**.

Local dev remains `npm run dev` in each app directory — deploy is separate.

## Emulators

```bash
cd frontend && npm ci --legacy-peer-deps && npm run build
firebase emulators:start --only hosting
```

Serves at http://localhost:5000
