# Final Evolution Lab Web Dashboard

This is the React web surface for Final Evolution Lab. It runs on Create React
App through CRACO and talks to the FastAPI backend under `../backend`.

## Setup

```bash
npm install
cp .env.example .env # optional; localhost defaults are built in
npm start
```

The app opens at http://localhost:3000. API calls default to
http://localhost:8000 when `REACT_APP_BACKEND_URL` is not set.

## Scripts

- `npm start` - start the CRACO dev server.
- `npm run build` - create the production build in `build/`.
- `npm test` - run CRA/Jest tests in watch mode.

## Environment

See `.env.example`.

- `REACT_APP_BACKEND_URL` points to the FastAPI host without `/api`.
- `REACT_APP_PAYPAL_CLIENT_ID` is optional; leave blank for local development.

## Notes

- Package manager is npm; commit changes to `package-lock.json`.
- The app currently uses React 19. Keep UI dependencies compatible with React 19
  when adding or upgrading packages.
