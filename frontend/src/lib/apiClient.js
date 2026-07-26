const DEFAULT_BACKEND_URL = "http://localhost:8000";

export const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || DEFAULT_BACKEND_URL;
export const API_URL = `${BACKEND_URL.replace(/\/$/, "")}/api`;

export function toWebSocketUrl(path) {
  const base = BACKEND_URL.replace(/\/$/, "").replace(/^https:/, "wss:").replace(/^http:/, "ws:");
  return `${base}${path.startsWith("/") ? path : `/${path}`}`;
}

export function getStoredUserId() {
  try {
    const raw = localStorage.getItem("fel_user_id") || localStorage.getItem("fel_session_user_id");
    return raw || "anonymous";
  } catch (_error) {
    return "anonymous";
  }
}

