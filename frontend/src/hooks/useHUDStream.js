import { useCallback, useEffect, useRef, useState } from "react";
import { toWebSocketUrl } from "@/lib/apiClient";

const MAX_RECONNECTS = 5;

export function useHUDStream(userId = "anonymous") {
  const [frame, setFrame] = useState(null);
  const [connected, setConnected] = useState(false);
  const [status, setStatus] = useState("idle");
  const wsRef = useRef(null);
  const reconnectAttempts = useRef(0);
  const reconnectTimer = useRef(null);

  const close = useCallback(() => {
    if (reconnectTimer.current) {
      clearTimeout(reconnectTimer.current);
      reconnectTimer.current = null;
    }
    wsRef.current?.close();
    wsRef.current = null;
  }, []);

  const connect = useCallback(() => {
    close();
    setStatus("connecting");
    const url = toWebSocketUrl(`/ws/hud?user_id=${encodeURIComponent(userId || "anonymous")}`);
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      setConnected(true);
      setStatus("connected");
      reconnectAttempts.current = 0;
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.event === "hud_connected" || data.event === "pong") {
          return;
        }
        setFrame(data);
      } catch (_error) {
        // Drop malformed HUD frames; the UE bridge should send JSON only.
      }
    };

    ws.onclose = () => {
      setConnected(false);
      if (reconnectAttempts.current >= MAX_RECONNECTS) {
        setStatus("offline");
        return;
      }
      const delay = Math.pow(2, reconnectAttempts.current) * 1000;
      reconnectTimer.current = setTimeout(() => {
        reconnectAttempts.current += 1;
        connect();
      }, delay);
    };

    ws.onerror = () => {
      setStatus("error");
      ws.close();
    };
  }, [close, userId]);

  useEffect(() => {
    connect();
    return close;
  }, [connect, close]);

  return { frame, connected, status, reconnect: connect };
}

