"use strict";
function mask(value) {
  const text = String(value || "");
  if (text.length < 4) return "***";
  return text.slice(0, 2) + "***" + text.slice(-1);
}
function safe(value) {
  const json = JSON.stringify(value, function (key, item) {
    if (/password|passwd|token|secret|otp|authorization|cookie|card|cvv/i.test(key)) return "<redacted>";
    return item;
  });
  return JSON.parse(json || "null");
}
module.exports = {mask, safe};
