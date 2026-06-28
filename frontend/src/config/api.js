const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const defaultBackendUrl = () => {
  if (process.env.REACT_APP_BACKEND_URL) {
    return process.env.REACT_APP_BACKEND_URL;
  }

  if (process.env.NODE_ENV === "production" && typeof window !== "undefined") {
    return window.location.origin;
  }

  return "http://localhost:8000";
};

export const BACKEND_URL = trimTrailingSlash(defaultBackendUrl());
export const API = `${BACKEND_URL}/api`;

export const toWebSocketUrl = (path = "") => {
  const protocolAwareBase = BACKEND_URL.replace(/^https?:/i, (protocol) =>
    protocol.toLowerCase() === "https:" ? "wss:" : "ws:",
  );
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return `${protocolAwareBase}${normalizedPath}`;
};
