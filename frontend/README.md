# Final Evolution Lab Frontend

React dashboard for the Final Evolution Lab athlete operating system.

## Setup

```bash
cp .env.example .env
yarn install
yarn start
```

The app serves at `http://localhost:3000` and defaults to `http://localhost:8000` for the backend when `REACT_APP_BACKEND_URL` is not set.

## Scripts

- `yarn start` - start the CRACO dev server.
- `yarn build` - create the production build in `build/`.
- `yarn test` - run the CRA/Jest test runner.

## Notes

- Keep the backend running for authenticated dashboard features.
- Pixel Streaming can use a pasted Eagle 3D iframe URL from the Pixel Stream tab.
- PayPal checkout requires both frontend and backend PayPal credentials; otherwise checkout degrades safely.
