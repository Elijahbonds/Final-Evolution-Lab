const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const getRuntimeOrigin = () => {
  if (typeof window === "undefined" || !window.location) return "";
  return window.location.origin;
};

const getLocalBackendUrl = () => {
  if (typeof window === "undefined" || !window.location) return "http://localhost:8001";
  const { protocol, hostname } = window.location;
  return `${protocol}//${hostname || "localhost"}:8001`;
};

const resolveBackendUrl = () => {
  const configured = process.env.REACT_APP_BACKEND_URL;
  if (configured && configured.trim()) return trimTrailingSlash(configured.trim());

  const origin = getRuntimeOrigin();
  if (!origin || /^(https?:\/\/)?(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) {
    return getLocalBackendUrl();
  }

  return trimTrailingSlash(origin);
};

export const BACKEND_URL = resolveBackendUrl();
export const API = `${BACKEND_URL}/api`;

export const toWebSocketUrl = (path = "") => {
  const base = BACKEND_URL.replace(/^http/i, "ws");
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${base}${normalizedPath}`;
};
