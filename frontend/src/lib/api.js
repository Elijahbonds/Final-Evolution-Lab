const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const defaultBackendUrl = () => {
  if (typeof window === "undefined") return "";
  const { protocol, hostname, host } = window.location;
  if (hostname === "localhost" || hostname === "127.0.0.1") {
    return "http://localhost:8000";
  }
  return `${protocol}//${host}`;
};

export const BACKEND_URL = trimTrailingSlash(
  process.env.REACT_APP_BACKEND_URL || defaultBackendUrl()
);

export const API = BACKEND_URL ? `${BACKEND_URL}/api` : "/api";
