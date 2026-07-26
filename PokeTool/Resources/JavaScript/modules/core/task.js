"use strict";
const errors = require("./errors");
async function create(input, index, total) {
  if (!input || typeof input !== "object" || typeof input.mode !== "string" || !input.mode) {
    throw errors.productError("INVALID_TASK", "Task requires a mode.");
  }
  JSON.stringify(input.payload === undefined ? null : input.payload);
  return {
    id:input.id || await PokeToolRuntime.system.uuid(),
    mode:input.mode, payload:input.payload === undefined ? null : input.payload,
    index:index, total:total, createdAt:input.createdAt || Date.now(),
    metadata:input.metadata || {}, status:"pending"
  };
}
module.exports = {create};
