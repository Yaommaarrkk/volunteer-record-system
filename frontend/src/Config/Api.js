const isLocal =
  globalThis.location.hostname === "127.0.0.1" ||
  globalThis.location.hostname === "localhost";

export const apiBaseUrl = isLocal
  ? "http://127.0.0.1:8080"
  : "https://volunteer-record-system.onrender.com";
