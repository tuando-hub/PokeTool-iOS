"use strict";
const bridge = require("./bridge-utils");
bridge.bind("Keychain", ["get","set","remove","contains"]);
PokeToolRuntime.secrets = Object.freeze({
  version: Native.Keychain.version,
  capabilities: () => Native.Keychain.capabilities(),
  get: (key, options) => Native.Keychain.get(key, options || null),
  set: (key, value, options) => Native.Keychain.set(key, value, options || null),
  remove: (key, options) => Native.Keychain.remove(key, options || null),
  has: (key, options) => Native.Keychain.contains(key, options || null)
});
module.exports = PokeToolRuntime.secrets;
