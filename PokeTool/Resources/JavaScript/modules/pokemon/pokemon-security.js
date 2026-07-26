"use strict";
function maskEmail(value) {
  const parts = String(value || "").split("@");
  if (parts.length !== 2) return "<private>";
  const local = parts[0];
  return (local.slice(0,2) || "*") + "***@" + parts[1];
}
function safeURL(value) {
  try {
    const parsed = new URL(String(value || ""));
    return parsed.origin + parsed.pathname;
  } catch (_) { return ""; }
}
function redact(value) {
  if (Array.isArray(value)) return value.map(redact);
  if (!value || typeof value !== "object") return value;
  const output = {};
  Object.keys(value).forEach(key => {
    output[key] = /password|pass|otp|token|cookie|authorization|card|cvv|cvc|pin/i.test(key)
      ? "<redacted>" : redact(value[key]);
  });
  return output;
}
module.exports = {maskEmail, safeURL, redact};
