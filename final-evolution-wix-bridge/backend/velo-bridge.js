/**
 * Sovereign Bridge — optional compatibility barrel (Cursor / imports).
 * Primary implementation: `velo-relay.jsw` · HTTP entry: `http-functions.js`
 *
 * If Velo rejects plain `.js` in `backend/`, delete this file and import
 * `velo-relay.jsw` only from `http-functions.js`.
 */
export {
  creditsForWixCents,
  relayToSupabase,
  buildOrderPaidPayloadFromRaw,
  executeWixOrderPaidFromAutomation,
} from "backend/velo-relay.jsw";
