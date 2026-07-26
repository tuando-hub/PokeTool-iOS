"use strict";
const errors = require("./errors");
async function create(input, index, total) {
  if (!input || typeof input !== "object" || typeof input.mode !== "string" || !input.mode) {
    throw errors.productError("INVALID_TASK", "Task requires a mode.");
  }
  JSON.stringify(input.payload === undefined ? null : input.payload);
  JSON.stringify(input.account === undefined ? null : input.account);
  JSON.stringify(input.input === undefined ? null : input.input);
  JSON.stringify(input.options === undefined ? null : input.options);
  return {
    id:input.id || await PokeToolRuntime.system.uuid(),
    mode:input.mode, payload:input.payload === undefined ? null : input.payload,
    index:index, total:total, createdAt:input.createdAt || Date.now(),
    metadata:input.metadata || {}, status:"pending",
    account:input.account || null,input:input.input || {},options:input.options || {}
  };
}
module.exports = {create};
