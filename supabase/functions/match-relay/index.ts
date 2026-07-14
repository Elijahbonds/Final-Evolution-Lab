// Supabase Edge Function: match-relay
// Handles NEXUS multiplayer lobby lifecycle (create / join / ready) and
// WebSocket relay for real-time NetMessage frames between peers.
//
// Routes:
//   POST /match-relay/create  → create a lobby, returns room_code
//   POST /match-relay/join    → join an existing lobby
//   POST /match-relay/ready   → mark player ready; auto-starts when all ready
//   GET  /match-relay/ws/:room_code → WebSocket relay channel

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl  = Deno.env.get("SUPABASE_URL")!;
const supabaseKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function supabase() {
  return createClient(supabaseUrl, supabaseKey);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function generateRoomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // unambiguous chars
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

// ── In-process relay map: room_code → Set<WebSocket> ────────────────────────
// NOTE: Each Edge Function invocation is isolated in Deno Deploy, so this map
// is per-instance.  For production multi-instance scale, replace with Supabase
// Realtime channels or a dedicated relay service.
const roomSockets = new Map<string, Set<WebSocket>>();

function broadcastToRoom(roomCode: string, frame: string, exclude?: WebSocket) {
  const sockets = roomSockets.get(roomCode);
  if (!sockets) return;
  for (const ws of sockets) {
    if (ws !== exclude && ws.readyState === WebSocket.OPEN) {
      ws.send(frame);
    }
  }
}

// ── Request handler ──────────────────────────────────────────────────────────

serve(async (req: Request) => {
  const url    = new URL(req.url);
  const method = req.method;

  // WebSocket upgrade: GET /match-relay/ws/:room_code
  const wsMatch = url.pathname.match(/^\/match-relay\/ws\/([A-Z0-9]{4,8})$/);
  if (wsMatch) {
    const roomCode = wsMatch[1];
    if (req.headers.get("upgrade") !== "websocket") {
      return json({ error: "WebSocket upgrade required" }, 426);
    }

    const { socket, response } = Deno.upgradeWebSocket(req);

    if (!roomSockets.has(roomCode)) {
      roomSockets.set(roomCode, new Set());
    }
    const sockets = roomSockets.get(roomCode)!;
    sockets.add(socket);

    socket.onmessage = (event) => {
      // Relay frame to all other peers in the room
      broadcastToRoom(roomCode, event.data as string, socket);
    };

    socket.onclose = () => {
      sockets.delete(socket);
      if (sockets.size === 0) {
        roomSockets.delete(roomCode);
      }
    };

    socket.onerror = () => {
      sockets.delete(socket);
    };

    return response;
  }

  // REST endpoints
  if (method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const db = supabase();

  // ── POST /match-relay/create ─────────────────────────────────────────────
  if (url.pathname === "/match-relay/create") {
    const modeId     = body["mode_id"]      as string | undefined;
    const hostUserId = body["host_user_id"] as string | undefined;
    const maxPlayers = (body["max_players"] as number | undefined) ?? 2;

    if (!modeId || !hostUserId) {
      return json({ error: "mode_id and host_user_id required" }, 400);
    }

    let roomCode = generateRoomCode();
    // Retry on collision (extremely unlikely)
    for (let attempts = 0; attempts < 5; attempts++) {
      const { data: existing } = await db
        .from("multiplayer_lobbies")
        .select("id")
        .eq("room_code", roomCode)
        .maybeSingle();
      if (!existing) break;
      roomCode = generateRoomCode();
    }

    const { data, error } = await db
      .from("multiplayer_lobbies")
      .insert({
        room_code:    roomCode,
        host_user_id: hostUserId,
        mode_id:      modeId,
        player_ids:   [hostUserId],
        max_players:  maxPlayers,
        status:       "waiting",
      })
      .select()
      .single();

    if (error || !data) {
      return json({ error: error?.message ?? "create failed" }, 500);
    }

    return json({
      id:           data.id,
      room_code:    data.room_code,
      host_user_id: data.host_user_id,
      mode_id:      data.mode_id,
      status:       data.status,
      max_players:  data.max_players,
    });
  }

  // ── POST /match-relay/join ───────────────────────────────────────────────
  if (url.pathname === "/match-relay/join") {
    const roomCode = body["room_code"] as string | undefined;
    const userId   = body["user_id"]   as string | undefined;

    if (!roomCode || !userId) {
      return json({ error: "room_code and user_id required" }, 400);
    }

    const { data: lobby, error: fetchErr } = await db
      .from("multiplayer_lobbies")
      .select("*")
      .eq("room_code", roomCode)
      .maybeSingle();

    if (fetchErr || !lobby) {
      return json({ error: "lobby not found" }, 404);
    }
    if (lobby.status !== "waiting") {
      return json({ error: "lobby is no longer accepting players" }, 409);
    }

    const playerIds = (lobby.player_ids as string[]) ?? [];
    if (!playerIds.includes(userId)) {
      if (playerIds.length >= lobby.max_players) {
        return json({ error: "lobby is full" }, 409);
      }
      playerIds.push(userId);
    }

    const { data: updated, error: updateErr } = await db
      .from("multiplayer_lobbies")
      .update({ player_ids: playerIds })
      .eq("room_code", roomCode)
      .select()
      .single();

    if (updateErr || !updated) {
      return json({ error: updateErr?.message ?? "join failed" }, 500);
    }

    return json({
      id:           updated.id,
      room_code:    updated.room_code,
      host_user_id: updated.host_user_id,
      mode_id:      updated.mode_id,
      status:       updated.status,
      player_count: playerIds.length,
    });
  }

  // ── POST /match-relay/ready ──────────────────────────────────────────────
  if (url.pathname === "/match-relay/ready") {
    const roomCode = body["room_code"] as string | undefined;
    const userId   = body["user_id"]   as string | undefined;

    if (!roomCode || !userId) {
      return json({ error: "room_code and user_id required" }, 400);
    }

    const { data: lobby, error: fetchErr } = await db
      .from("multiplayer_lobbies")
      .select("*")
      .eq("room_code", roomCode)
      .maybeSingle();

    if (fetchErr || !lobby) {
      return json({ error: "lobby not found" }, 404);
    }

    const readyIds  = (lobby.ready_ids  as string[]) ?? [];
    const playerIds = (lobby.player_ids as string[]) ?? [];

    if (!readyIds.includes(userId)) {
      readyIds.push(userId);
    }

    // Start match when all players are ready
    const allReady = playerIds.every((pid: string) => readyIds.includes(pid));
    const newStatus = allReady ? "active" : "waiting";

    const { data: updated, error: updateErr } = await db
      .from("multiplayer_lobbies")
      .update({ ready_ids: readyIds, status: newStatus })
      .eq("room_code", roomCode)
      .select()
      .single();

    if (updateErr || !updated) {
      return json({ error: updateErr?.message ?? "ready failed" }, 500);
    }

    // Broadcast lobby_event so all connected peers know the match started
    if (allReady) {
      broadcastToRoom(roomCode, JSON.stringify({
        kind:      "lobby_event",
        room_code: roomCode,
        payload:   { event: "match_start", mode_id: lobby.mode_id },
        timestamp: Date.now() / 1000,
      }));
    }

    return json({
      room_code: updated.room_code,
      status:    updated.status,
      ready_ids: readyIds,
      all_ready: allReady,
    });
  }

  return json({ error: "unknown endpoint" }, 404);
});
