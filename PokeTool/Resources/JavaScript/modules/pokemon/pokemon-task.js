"use strict";
const errors = require("./pokemon-errors");
const MODES = Object.freeze([
  "pokemon.create","pokemon.lottery","pokemon.checkResult",
  "pokemon.changeProfileOrder","pokemon.changeEmail","pokemon.buy"
]);
function validate(raw) {
  if (!raw || typeof raw !== "object" || !MODES.includes(raw.mode)) {
    throw errors.create("POKEMON_INVALID_TASK", "Unknown Pokémon task mode.");
  }
  const task = Object.assign({input:{},options:{},metadata:{}}, raw);
  if (!task.id || !task.account || typeof task.account.email !== "string") {
    throw errors.create("POKEMON_INVALID_TASK", "Task id and account email are required.");
  }
  if (typeof task.account.password !== "string" || !task.account.password) {
    throw errors.create("POKEMON_INVALID_TASK", "Account password is required.");
  }
  if (task.mode === "pokemon.changeEmail" && !task.input.newEmail) {
    throw errors.create("POKEMON_INVALID_TASK", "New email is required.");
  }
  if (task.mode === "pokemon.lottery" &&
      !(Array.isArray(task.input.productIds) && task.input.productIds.length)) {
    throw errors.create("POKEMON_INVALID_TASK", "Lottery productIds are required.");
  }
  if (task.mode === "pokemon.buy" && !task.input.productURL) {
    throw errors.create("POKEMON_INVALID_TASK", "Buy productURL is required.");
  }
  task.options.allowFinalSubmit = task.options.allowFinalSubmit === true;
  return task;
}
module.exports = {MODES,validate};
