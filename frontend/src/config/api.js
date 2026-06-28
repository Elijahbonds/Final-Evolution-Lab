const configuredBackendUrl = process.env.REACT_APP_BACKEND_URL;

const defaultBackendUrl =
  process.env.NODE_ENV === "development" ? "http://localhost:8000" : window.location.origin;

export const BACKEND_URL = (configuredBackendUrl || defaultBackendUrl).replace(/\/$/, "");
export const API = `${BACKEND_URL}/api`;
