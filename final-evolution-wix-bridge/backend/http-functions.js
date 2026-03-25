/**
 * Wix Velo — HTTP Functions (required filename for Velo).
 * Routes: POST /_functions/felRelayWixOrder  |  POST /_functions/felWixOrderPaidFromAutomation
 *
 * @see https://dev.wix.com/docs/develop-websites/articles/coding-with-velo/code-http-functions
 */
import { ok, badRequest, serverError } from "wix-http-functions";
import {
  relayToSupabase,
  executeWixOrderPaidFromAutomation,
} from "backend/velo-relay.jsw";

/**
 * Generic relay — pass through JSON (manual Automations or custom mappers).
 * POST /_functions/felRelayWixOrder
 */
export async function post_felRelayWixOrder(request) {
  try {
    const body = await request.body.json();
    const text = await relayToSupabase(body);
    return ok({ body: text, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return badRequest({ body: String(e && e.message ? e.message : e) });
  }
}

/**
 * Order paid — maps cents → shard_delta, forwards athlete_id + supabase_user_id.
 * POST /_functions/felWixOrderPaidFromAutomation
 */
export async function post_felWixOrderPaidFromAutomation(request) {
  try {
    const raw = await request.body.json();
    const result = await executeWixOrderPaidFromAutomation(raw);
    if (!result.ok) {
      return badRequest({ body: result.error });
    }
    return ok({ body: result.text, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return serverError({ body: String(e && e.message ? e.message : e) });
  }
}
