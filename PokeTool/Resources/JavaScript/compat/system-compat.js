"use strict";
const bridge = require("./bridge-utils");
bridge.bind("System", [
  "appInfo","runtimeInfo","now","monotonicNow","sleep","generateUUID",
  "randomBytes","memoryInfo","environment"
]);
PokeToolRuntime.system = Object.freeze({
  version: Native.System.version,
  capabilities: () => Native.System.capabilities(),
  appInfo: () => Native.System.appInfo(),
  runtimeInfo: () => Native.System.runtimeInfo(),
  now: () => Native.System.now(),
  monotonicNow: () => Native.System.monotonicNow(),
  sleep: milliseconds => Native.System.sleep(milliseconds),
  uuid: () => Native.System.generateUUID(),
  randomBytes: length => Native.System.randomBytes(length, "base64"),
  memoryInfo: () => Native.System.memoryInfo(),
  environment: () => Native.System.environment()
});
module.exports = PokeToolRuntime.system;
