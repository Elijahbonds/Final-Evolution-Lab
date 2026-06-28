const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const isLocalHost = (hostname) => ["localhost", "127.0.0.1", ""].includes(hostname);

const resolveBackendUrl = () => {
  const configuredUrl = process.env.REACT_APP_BACKEND_URL;
  if (configuredUrl) {
    return trimTrailingSlash(configuredUrl);
  }

  if (typeof window !== "undefined" && window.location?.origin && !isLocalHost(window.location.hostname)) {
    return trimTrailingSlash(window.location.origin);
  }

  return "http://localhost:8000";
};

export const BACKEND_URL = resolveBackendUrl();
export const API = `${BACKEND_URL}/api`;

export const toWebSocketUrl = (path = "") => {
  const wsBase = BACKEND_URL.replace(/^https:/, "wss:").replace(/^http:/, "ws:");
  const wsPath = path.startsWith("/") ? path : `/${path}`;
  return `${wsBase}${wsPath}`;
};
