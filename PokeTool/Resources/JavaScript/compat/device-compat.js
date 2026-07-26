"use strict";
const bridge = require("./bridge-utils");
bridge.bind("Device", ["info","isLowPowerMode","memoryInfo"]);
PokeToolRuntime.device = Object.freeze({
  version: Native.Device.version,
  capabilities: () => Native.Device.capabilities(),
  info: () => Native.Device.info(),
  installationId: () => Promise.reject(Object.assign(new Error("Installation ID is not available."), {
    name:"DeviceError", code:"UNSUPPORTED_OPERATION"
  })),
  isLowPowerMode: () => Native.Device.isLowPowerMode(),
  memoryInfo: () => Native.Device.memoryInfo()
});
module.exports = PokeToolRuntime.device;
