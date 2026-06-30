# Final Evolution Lab frontend

CRA + CRACO React app for the Final Evolution Lab athlete OS, game mode dashboard, Pixel Stream console, BioFuel, and coaching surfaces.

## Environment

Copy `.env.example` to `.env` when you need overrides:

```bash
cp .env.example .env
```

`REACT_APP_BACKEND_URL` is optional in local development; when unset on `localhost`, the app defaults to `http://localhost:8000`.

## Scripts

```bash
npm start
npm run build
npm test -- --watchAll=false --passWithNoTests
```

The production bundle is emitted to `build/`. Vercel rewrites all non-asset routes to `index.html` so `/dashboard`, `/download`, and `/login` can be refreshed directly.
