"use strict";
const bridge = require("./bridge-utils");
bridge.bind("System", [
  "appInfo","runtimeInfo","now","monotonicNow","sleep","generateUUID",
  "randomBytes","memoryInfo","environment"
]);
const invoke = (method, args) => bridge.invoke("System", method, args || []);
PokeToolRuntime.system = Object.freeze({
  version: Native.System.version,
  capabilities: () => Native.System.capabilities(),
  appInfo: () => invoke("appInfo"),
  runtimeInfo: () => invoke("runtimeInfo"),
  now: () => invoke("now"),
  monotonicNow: () => invoke("monotonicNow"),
  sleep: milliseconds => invoke("sleep", [milliseconds]),
  uuid: () => invoke("generateUUID"),
  randomBytes: length => invoke("randomBytes", [length, "base64"]),
  memoryInfo: () => invoke("memoryInfo"),
  environment: () => invoke("environment")
});
module.exports = PokeToolRuntime.system;
