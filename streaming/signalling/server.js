/**
 * FEL Pixel Streaming Signalling Server
 *
 * Relays WebRTC signalling between:
 *   - UE5 Game Server (streamer) connecting on STREAMER_PORT
 *   - Web browser clients (players) connecting on PLAYER_PORT
 *
 * Also handles FEL-specific data channel routing for mode launching,
 * exercise demos, and status queries.
 */

const http = require('http');
const express = require('express');
const { WebSocketServer, WebSocket } = require('ws');
const { v4: uuidv4 } = require('uuid');

const STREAMER_PORT = parseInt(process.env.STREAMER_PORT || '8889');
const PLAYER_PORT = parseInt(process.env.PLAYER_PORT || '8888');
const LOG_LEVEL = process.env.FEL_LOG_LEVEL || 'info';

// ---- State ----
let streamer = null; // Single streamer connection (UE5)
const players = new Map(); // playerId -> WebSocket
let activeModeKey = null;
let streamingSessionId = null;

function log(level, ...args) {
  if (level === 'debug' && LOG_LEVEL !== 'debug') return;
  const ts = new Date().toISOString();
  console.log(`[${ts}] [${level.toUpperCase()}]`, ...args);
}

// ---- Streamer Server (UE5 connects here) ----
const streamerApp = express();
const streamerHttpServer = http.createServer(streamerApp);
const streamerWss = new WebSocketServer({ server: streamerHttpServer });

streamerWss.on('connection', (ws) => {
  if (streamer) {
    log('warn', 'New streamer connected, replacing existing');
    streamer.close();
  }
  streamer = ws;
  streamingSessionId = uuidv4();
  log('info', `Streamer connected (session: ${streamingSessionId})`);

  ws.on('message', (raw) => {
    const msg = raw.toString();
    log('debug', 'Streamer ->', msg.substring(0, 200));

    // Route to all connected players
    try {
      const parsed = JSON.parse(msg);

      // If message targets a specific player
      if (parsed.playerId && players.has(parsed.playerId)) {
        const player = players.get(parsed.playerId);
        if (player.readyState === WebSocket.OPEN) {
          player.send(msg);
        }
      } else {
        // Broadcast to all players
        for (const [id, player] of players) {
          if (player.readyState === WebSocket.OPEN) {
            player.send(msg);
          }
        }
      }
    } catch {
      // Binary or non-JSON: forward to all players
      for (const [id, player] of players) {
        if (player.readyState === WebSocket.OPEN) {
          player.send(raw);
        }
      }
    }
  });

  ws.on('close', () => {
    log('info', 'Streamer disconnected');
    streamer = null;
    streamingSessionId = null;
    activeModeKey = null;
  });

  ws.on('error', (err) => {
    log('error', 'Streamer error:', err.message);
  });
});

// ---- Player Server (browsers connect here) ----
const playerApp = express();
const playerHttpServer = http.createServer(playerApp);
const playerWss = new WebSocketServer({ server: playerHttpServer });

// Health check endpoint
playerApp.get('/healthz', (req, res) => {
  res.json({
    status: 'ok',
    streamerConnected: !!streamer,
    playerCount: players.size,
    activeMode: activeModeKey,
    sessionId: streamingSessionId
  });
});

// Mode manifest endpoint (REST fallback)
playerApp.get('/api/modes', (req, res) => {
  res.json({
    modes: [
      { id: 'basketball_h2h', displayName: 'Street \u00b7 1v1', venue: 'VeniceBeach', category: 'basketball' },
      { id: 'basketball_dunk', displayName: 'Dunk Contest', venue: 'VeniceBeach', category: 'basketball' },
      { id: 'basketball_3v3', displayName: 'Street \u00b7 3v3', venue: 'VeniceBeach', category: 'basketball' },
      { id: 'karate_h2h', displayName: 'Karate \u00b7 1v1', venue: 'Dojo', category: 'combat' },
      { id: 'karate_endless', displayName: 'Karate \u00b7 Endless', venue: 'Dojo', category: 'combat' },
      { id: 'baseball', displayName: 'Baseball \u00b7 Ballpark', venue: 'BaseballPark', category: 'field' },
      { id: 'football', displayName: 'Football \u00b7 Kick Return', venue: 'Gridiron', category: 'field' },
      { id: 'soccer', displayName: 'Soccer \u00b7 Stadium', venue: 'SoccerStadium', category: 'field' },
      { id: 'golf', displayName: 'Golf \u00b7 Links', venue: 'Links', category: 'precision' },
      { id: 'tennis', displayName: 'Tennis \u00b7 Court', venue: 'TennisCourt', category: 'court' },
      { id: 'volleyball', displayName: 'Volleyball \u00b7 Sand', venue: 'SandCourt', category: 'court' },
      { id: 'gymnastics', displayName: 'Gymnastics \u00b7 Floor', venue: 'TrainingFloor', category: 'performance' },
      { id: 'brain_brawl', displayName: 'Academy \u00b7 Brain Brawl', venue: 'NeuroArena', category: 'academy' },
      { id: 'surfing', displayName: 'Surf \u00b7 Line', venue: 'VeniceBeach', category: 'board' },
      { id: 'skateboarding', displayName: 'Skate \u00b7 Park', venue: 'Dojo', category: 'board' },
      { id: 'snowboarding', displayName: 'Snow \u00b7 Line', venue: 'TrainingFloor', category: 'board' },
      { id: 'market_browse', displayName: 'Sovereign Shop', venue: 'LumaVeniceShop', category: 'shop' }
    ]
  });
});

playerWss.on('connection', (ws) => {
  const playerId = uuidv4();
  players.set(playerId, ws);
  log('info', `Player connected: ${playerId} (total: ${players.size})`);

  // Send player their ID and current status
  ws.send(JSON.stringify({
    type: 'playerConnected',
    playerId,
    streamerConnected: !!streamer,
    activeMode: activeModeKey,
    sessionId: streamingSessionId
  }));

  ws.on('message', (raw) => {
    const msg = raw.toString();
    log('debug', `Player ${playerId} ->`, msg.substring(0, 200));

    try {
      const parsed = JSON.parse(msg);

      // Track mode launches for status
      if (parsed.command === 'launch_mode' && parsed.payload?.mode_key) {
        activeModeKey = parsed.payload.mode_key;
        log('info', `Mode launched: ${activeModeKey}`);
      }
      if (parsed.command === 'exit_mode') {
        activeModeKey = null;
        log('info', 'Mode exited');
      }

      // Forward to streamer with player ID
      if (streamer && streamer.readyState === WebSocket.OPEN) {
        parsed.playerId = playerId;
        streamer.send(JSON.stringify(parsed));
      } else {
        ws.send(JSON.stringify({
          type: 'error',
          message: 'No streamer connected. Please wait for the game server to start.'
        }));
      }
    } catch {
      // Binary or non-JSON: forward directly
      if (streamer && streamer.readyState === WebSocket.OPEN) {
        streamer.send(raw);
      }
    }
  });

  ws.on('close', () => {
    players.delete(playerId);
    log('info', `Player disconnected: ${playerId} (total: ${players.size})`);

    // Notify streamer
    if (streamer && streamer.readyState === WebSocket.OPEN) {
      streamer.send(JSON.stringify({
        type: 'playerDisconnected',
        playerId
      }));
    }
  });

  ws.on('error', (err) => {
    log('error', `Player ${playerId} error:`, err.message);
  });
});

// ---- Start ----
streamerHttpServer.listen(STREAMER_PORT, () => {
  log('info', `FEL Signalling — Streamer port: ${STREAMER_PORT}`);
});

playerHttpServer.listen(PLAYER_PORT, () => {
  log('info', `FEL Signalling — Player port: ${PLAYER_PORT}`);
  log('info', `Health: http://localhost:${PLAYER_PORT}/healthz`);
  log('info', `Modes: http://localhost:${PLAYER_PORT}/api/modes`);
});

process.on('SIGTERM', () => {
  log('info', 'Shutting down...');
  streamerHttpServer.close();
  playerHttpServer.close();
  process.exit(0);
});
