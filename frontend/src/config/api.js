const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const defaultBackendUrl =
  process.env.NODE_ENV === "development"
    ? "http://localhost:8000"
    : (typeof window !== "undefined" ? window.location.origin : "");

export const BACKEND_URL = trimTrailingSlash(
  process.env.REACT_APP_BACKEND_URL || defaultBackendUrl
);

export const API = `${BACKEND_URL}/api`;

export const toWebSocketUrl = (path) => {
  const base = BACKEND_URL.replace(/^http/i, "ws");
  return `${base}${path.startsWith("/") ? path : `/${path}`}`;
};
