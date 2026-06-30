# Final Evolution Lab Frontend

React/CRACO web client for the Final Evolution Lab athlete OS, coach hub, and game/Pixel Streaming dashboard.

## Setup

```bash
npm install --legacy-peer-deps
cp .env.example .env
```

Local development defaults API calls to `http://localhost:8000` when `REACT_APP_BACKEND_URL` is not set. Production builds default API calls to the current origin unless `REACT_APP_BACKEND_URL` is provided.

## Scripts

- `npm start` - run the development server.
- `npm run build` - create the production build in `build/`.
- `npm test -- --watchAll=false --passWithNoTests` - run the CRA test command in CI mode.

## Environment

See `.env.example` for supported variables:

- `REACT_APP_BACKEND_URL` - FastAPI backend origin.
- `REACT_APP_PAYPAL_CLIENT_ID` - optional PayPal client ID for purchase flows.
- `REACT_APP_FIREBASE_*` - Firebase Hosting/app config used by deploy workflows.

## CI notes

This package uses npm and commits `package-lock.json`. GitHub Actions should install with `npm install --legacy-peer-deps` to preserve the current React 19/CRA compatibility constraints.
