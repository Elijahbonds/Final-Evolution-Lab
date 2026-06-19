const trimTrailingSlash = (value) => value.replace(/\/+$/, "");

const defaultBackendUrl =
  process.env.NODE_ENV === "development"
    ? "http://localhost:8000"
    : window.location.origin;

export const BACKEND_URL = trimTrailingSlash(
  process.env.REACT_APP_BACKEND_URL || defaultBackendUrl
);
export const API = `${BACKEND_URL}/api`;
