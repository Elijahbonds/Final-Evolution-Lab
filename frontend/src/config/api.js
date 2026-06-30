const rawBackendUrl = process.env.REACT_APP_BACKEND_URL;

const defaultBackendUrl =
  typeof window !== "undefined" &&
  (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1")
    ? "http://localhost:8000"
    : window.location.origin;

export const BACKEND_URL = (rawBackendUrl || defaultBackendUrl).replace(/\/$/, "");
export const API = `${BACKEND_URL}/api`;

export const toWebSocketUrl = (path = "") => {
  const wsBase = BACKEND_URL.replace(/^https:/, "wss:").replace(/^http:/, "ws:");
  return `${wsBase}${path.startsWith("/") ? path : `/${path}`}`;
};
