"use strict";
const constants = require("./constants");
const errors = require("./errors");
const cancellation = require("./cancellation");
const task = require("./task");
const result = require("./result");
const diagnostics = require("./diagnostics");
const stateModule = require("./state");
const state = new stateModule.ProductState(PokeToolRuntime.events);
module.exports = {
  version:"1.0.0", constants, errors, cancellation, task, result, diagnostics, state,
  updateCurrent:patch => state.update(patch),
  current:() => state.snapshot(),
  reset:() => state.reset()
};
