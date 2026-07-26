"use strict";
function productError(code, message, context, cause) {
  const error = new Error(message);
  error.name = "ProductError";
  error.code = code;
  error.step = context && context.step || null;
  error.flowId = context && context.flowId || null;
  error.taskId = context && context.taskId || null;
  error.retryable = Boolean(context && context.retryable);
  error.causeCode = cause && cause.code || null;
  error.diagnostics = context && context.diagnostics || null;
  return error;
}
function wrap(error, context) {
  if (error && error.name === "ProductError") return error;
  return productError(
    error && error.code || "INTERNAL_FLOW_ERROR",
    error && error.message || "Product runtime operation failed.",
    Object.assign({}, context, {retryable:Boolean(error && error.retryable)}), error
  );
}
module.exports = {productError, wrap};
