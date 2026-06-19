# Final Evolution Lab Frontend

React/CRACO web app for the Final Evolution Lab athlete OS.

## Setup

```bash
npm install
cp .env.example .env
npm start
```

The dev server runs at http://localhost:3000. API calls default to http://localhost:8000 in development when `REACT_APP_BACKEND_URL` is not set.

## Scripts

- `npm start` - start the CRACO dev server
- `npm run build` - create a production build in `build/`
- `npm test` - run the CRA test runner

## Environment

See `.env.example` for supported variables:

- `REACT_APP_BACKEND_URL` - FastAPI base URL
- `REACT_APP_PAYPAL_CLIENT_ID` - optional PayPal client id for checkout
