const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const resolveBackendUrl = () => {
  const configured = process.env.REACT_APP_BACKEND_URL;
  if (configured) return trimTrailingSlash(configured);

  if (typeof window !== "undefined") {
    const { protocol, hostname, origin } = window.location;
    const isLocalHost = hostname === "localhost" || hostname === "127.0.0.1";

    if (isLocalHost) {
      return `${protocol}//${hostname}:8000`;
    }

    return origin;
  }

  return "http://localhost:8000";
};

export const BACKEND_URL = resolveBackendUrl();
export const API = `${BACKEND_URL}/api`;

export const toWebSocketUrl = (path) => {
  const wsBase = BACKEND_URL.replace(/^http/i, "ws");
  return `${wsBase}${path}`;
};
