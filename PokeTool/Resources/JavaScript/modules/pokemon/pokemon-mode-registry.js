"use strict";
const errors = require("./pokemon-errors");
const modules = Object.freeze({
  "pokemon.create":require("./pokemon-create-mode"),
  "pokemon.lottery":require("./pokemon-lottery-mode"),
  "pokemon.checkResult":require("./pokemon-check-result-mode"),
  "pokemon.changeProfileOrder":require("./pokemon-change-profile-order-mode"),
  "pokemon.changeEmail":require("./pokemon-change-email-mode"),
  "pokemon.buy":require("./pokemon-buy-mode")
});
function resolve(mode) {
  const value = modules[mode];
  if (!value || typeof value.execute !== "function") throw errors.create("POKEMON_INVALID_TASK", "Pokemon mode is not registered.");
  return value;
}
module.exports = {modes:Object.keys(modules),resolve};
