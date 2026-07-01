/**
 * test_ws_client.js — Simulates two players in a match for local dev testing.
 *
 * Run:
 *   REACT_APP_BACKEND_URL=http://localhost:8001 node src/test_ws_client.js
 *
 * Or directly:
 *   node src/test_ws_client.js <API_BASE> <match_id_or_new>
 *
 * What it does:
 *   1. Player A creates a match via POST /api/matches/create
 *   2. Both Player A and Player B connect via WebSocket /ws/match/{match_id}
 *   3. Player B joins via POST /api/matches/join  → match becomes 'active'
 *   4. Both clients listen for 15s and print all received messages
 */
const http = require('http');
const https = require('https');
const { URL } = require('url');

// ── Config ─────────────────────────────────────────────────────────────────
const API_BASE = process.env.REACT_APP_BACKEND_URL
  || process.argv[2]
  || 'http://localhost:8001';

const EXISTING_MATCH_ID = process.argv[3] || null;
const LISTEN_SECONDS = 15;

// ── Helpers ─────────────────────────────────────────────────────────────────
function post(path, body = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE);
    const data = JSON.stringify(body);
    const mod = url.protocol === 'https:' ? https : http;
    const req = mod.request(
      { hostname: url.hostname, port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname, method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } },
      (res) => {
        let buf = '';
        res.on('data', (d) => { buf += d; });
        res.on('end', () => {
          try { resolve(JSON.parse(buf)); } catch { resolve(buf); }
        });
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function openWs(matchId, label) {
  const wsUrl = API_BASE.replace(/^http/, 'ws') + `/ws/match/${matchId}`;
  // Try native WebSocket (Node 21+) or ws package
  let WS;
  try {
    WS = require('ws');
  } catch {
    WS = WebSocket; // Node 21+ global
  }
  const ws = new WS(wsUrl);
  ws.on('open', () => console.log(`[${label}] WS connected to ${wsUrl}`));
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    console.log(`[${label}] ← ${msg.type}:`, JSON.stringify(msg).slice(0, 200));
  });
  ws.on('close', () => console.log(`[${label}] WS closed`));
  ws.on('error', (e) => console.error(`[${label}] WS error:`, e.message));
  return ws;
}

// ── Main ────────────────────────────────────────────────────────────────────
async function main() {
  try {
    let matchId = EXISTING_MATCH_ID;

    if (!matchId) {
      console.log('[PlayerA] Creating match…');
      const created = await post('/api/matches/create', { mode_id: 'basketball_h2h' });
      matchId = created.match_id;
      console.log(`[PlayerA] Match created: ${matchId} (status=${created.status})`);
    } else {
      console.log(`[PlayerA] Using existing match: ${matchId}`);
    }

    // Both clients connect WS before joining (to observe match_start event)
    const wsA = openWs(matchId, 'PlayerA');
    const wsB = openWs(matchId, 'PlayerB');

    // Small delay to let WS handshake complete
    await new Promise((r) => setTimeout(r, 800));

    // Player B joins (triggers match_start broadcast when 2 players present)
    console.log('[PlayerB] Joining match…');
    const joined = await post('/api/matches/join', { match_id: matchId, player_id: 'player_b' });
    console.log(`[PlayerB] Join response:`, joined);

    console.log(`\nListening for ${LISTEN_SECONDS}s… (expect match_start + score_events)\n`);
    await new Promise((r) => setTimeout(r, LISTEN_SECONDS * 1000));

    wsA.close();
    wsB.close();
    console.log('\nDone. Check above for match_start and score_event messages.');
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
