const normalizeBackendUrl = (rawUrl) => {
  if (rawUrl && rawUrl.trim()) {
    return rawUrl.replace(/\/+$/, "");
  }

  if (typeof window !== "undefined" && window.location?.origin) {
    return window.location.origin;
  }

  return "";
};

export const BACKEND_URL = normalizeBackendUrl(process.env.REACT_APP_BACKEND_URL);
export const API = BACKEND_URL ? `${BACKEND_URL}/api` : "/api";

