"use strict";
const core = require("../core/core-entry");
const runner = require("../runner/runner-entry");
const flow = require("/runtime/web-flow-engine");
module.exports = Object.freeze({
  version:"1.0.0",
  capabilities:Object.freeze({
    sequentialRunner:true, multiSignalPageGuard:true,
    verifiedTransitions:true, boundedRetry:true, boundedRecovery:true,
    checkpoints:"foundation", accountQueue:"foundation", parallelRunner:false,
    websiteModes:false, otp:false
  }),
  core, runner, flow
});
