const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const inferBackendUrl = () => {
  const configured = process.env.REACT_APP_BACKEND_URL;
  if (configured) return trimTrailingSlash(configured);

  if (typeof window === "undefined") {
    return "http://localhost:8000";
  }

  const { protocol, hostname } = window.location;
  const isLocalHost = hostname === "localhost" || hostname === "127.0.0.1";
  if (isLocalHost) {
    return "http://localhost:8000";
  }

  return `${protocol}//${window.location.host}`;
};

export const BACKEND_URL = inferBackendUrl();
export const API = `${BACKEND_URL}/api`;

export const toWebSocketUrl = (path) => {
  const wsBase = BACKEND_URL.replace(/^https:/, "wss:").replace(/^http:/, "ws:");
  return `${wsBase}${path.startsWith("/") ? path : `/${path}`}`;
};
