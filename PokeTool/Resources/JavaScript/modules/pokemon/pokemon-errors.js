"use strict";
const CODES = Object.freeze([
  "POKEMON_INVALID_TASK","POKEMON_LOGIN_PAGE_MISMATCH","POKEMON_INVALID_CREDENTIAL",
  "POKEMON_ACCOUNT_LOCKED","POKEMON_CAPTCHA_REQUIRED","POKEMON_MAINTENANCE",
  "POKEMON_RATE_LIMITED","POKEMON_SESSION_EXPIRED","POKEMON_TERMS_REQUIRED",
  "POKEMON_MYPAGE_NOT_REACHED","POKEMON_REGISTRATION_FAILED",
  "POKEMON_ACCOUNT_ALREADY_EXISTS","POKEMON_OTP_REQUIRED","POKEMON_OTP_FAILED",
  "POKEMON_ENTRY_UNAVAILABLE","POKEMON_ALREADY_ENTERED","POKEMON_ENTRY_CLOSED",
  "POKEMON_NOT_ELIGIBLE","POKEMON_RESULT_PENDING","POKEMON_RESULT_UNAVAILABLE",
  "POKEMON_PROFILE_UPDATE_FAILED","POKEMON_EMAIL_CHANGE_FAILED",
  "POKEMON_PRODUCT_NOT_FOUND","POKEMON_OUT_OF_STOCK","POKEMON_PURCHASE_LIMIT",
  "POKEMON_CART_FAILED","POKEMON_CHECKOUT_FAILED","POKEMON_PAYMENT_REJECTED",
  "POKEMON_ORDER_FAILED","POKEMON_PURCHASE_STATE_UNKNOWN","POKEMON_PAGE_MISMATCH",
  "POKEMON_UNEXPECTED_PAGE","POKEMON_RETRY_EXHAUSTED","POKEMON_CANCELLED",
  "POKEMON_RUNTIME_STOPPED","POKEMON_INTERNAL_ERROR"
]);
function create(code, message, context, cause) {
  const error = new Error(message);
  error.name = "PokemonError";
  error.code = CODES.includes(code) ? code : "POKEMON_INTERNAL_ERROR";
  error.step = context && context.step || null;
  error.retryable = Boolean(context && context.retryable);
  error.causeCode = cause && cause.code || null;
  error.diagnostics = context && context.diagnostics || null;
  return error;
}
function wrap(error, context) {
  if (error && error.name === "PokemonError") return error;
  if (error && ["TASK_CANCELLED","OPERATION_CANCELLED","CANCELLED"].includes(error.code)) {
    return create("POKEMON_CANCELLED", "Pokemon task was cancelled.", context, error);
  }
  return create("POKEMON_INTERNAL_ERROR", error && error.message || "Pokemon operation failed.", context, error);
}
module.exports = {CODES,create,wrap};
