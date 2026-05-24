#!/usr/bin/env python3
"""
ws_hud_server.py — FEL HUD WebSocket relay server stub.
Listens on ws://localhost:8080/ws/hud.
Gameplay subsystems (UE5 C++, backend, tests) connect and broadcast
JSON messages to all connected HUD overlay clients.

Message format:
  { "type": "<message_type>", "payload": { ... } }

Supported types:
  score_update    → { home_score, away_score, timer_seconds, period }
  prq_update      → { prq_score, mode_weight_label, max_prq }
  economy_update  → { shards, xp, xp_cap }
  mri_update      → { mri_score, arv, esi, pacing }
  coach_tip       → { tip_text, mode_name }
  game_event      → { event_type, description, timestamp }

Usage:
  pip install websockets
  python ws_hud_server.py [--port 8080]
"""

import asyncio
import json
import argparse
import logging
import time
import websockets
from websockets.server import WebSocketServerProtocol

logging.basicConfig(level=logging.INFO, format='[FEL HUD] %(levelname)s %(message)s')
logger = logging.getLogger(__name__)

CONNECTED: set[WebSocketServerProtocol] = set()


async def handler(ws: WebSocketServerProtocol):
    CONNECTED.add(ws)
    logger.info(f"Client connected: {ws.remote_address} — total={len(CONNECTED)}")
    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
                logger.info(f"Relay → {msg.get('type')} to {len(CONNECTED)-1} peers")
                # Broadcast to all OTHER connected clients
                peers = {c for c in CONNECTED if c != ws}
                if peers:
                    await asyncio.gather(*[p.send(raw) for p in peers], return_exceptions=True)
            except json.JSONDecodeError:
                await ws.send(json.dumps({"error": "invalid_json"}))
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        CONNECTED.discard(ws)
        logger.info(f"Client disconnected — total={len(CONNECTED)}")


async def main(port: int):
    logger.info(f"FEL HUD WebSocket server starting on ws://localhost:{port}/ws/hud")
    async with websockets.serve(handler, "localhost", port):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    args = ap.parse_args()
    asyncio.run(main(args.port))
