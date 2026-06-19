# Final Evolution Lab Frontend

React/CRACO web dashboard for the Final Evolution Lab athlete operating system.

## Setup

```bash
npm install
cp .env.example .env
npm start
```

The development server runs at http://localhost:3000.

If `REACT_APP_BACKEND_URL` is not set, localhost defaults to `http://localhost:8000` and deployed hosts fall back to same-origin `/api`.

## Scripts

```bash
npm start      # run development server
npm test       # run CRA test runner
npm run build  # create production build in build/
```

Vercel uses `npm install`, `npm run build`, and serves the `build` directory.

## Key routes

- `/` landing page
- `/download` distribution and onboarding hub
- `/dashboard` authenticated athlete dashboard
- Dashboard sidebar -> **Pixel Stream** for the Pixel Streaming control surface

Backend environment notes live in `../backend/.env.example`.
