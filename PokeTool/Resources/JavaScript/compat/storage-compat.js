"use strict";
const bridge = require("./bridge-utils");
const methods = [
  "get","set","remove","contains","keys","clear",
  "readText","writeText","readJSON","writeJSON","readBinary","writeBinary",
  "exists","info","list","createDirectory","removePath","move","copy",
  "temporaryFile","cleanupTemporary"
];
bridge.bind("Storage", methods);

const storage = {
  version: Native.Storage.version,
  capabilities: () => Native.Storage.capabilities(),
  get: async function (key, defaultValue) {
    const value = await bridge.invoke("Storage", "get", [key]);
    return value === null && arguments.length > 1 ? defaultValue : value;
  },
  set: (key, value) => bridge.invoke("Storage", "set", [key, value]),
  remove: key => bridge.invoke("Storage", "remove", [key]),
  has: key => bridge.invoke("Storage", "contains", [key]),
  keys: prefix => bridge.invoke("Storage", "keys", [prefix]),
  clear: prefix => bridge.invoke("Storage", "clear", [prefix]),
  readText: path => bridge.invoke("Storage", "readText", [path]),
  writeText: (path, content, options) => bridge.invoke("Storage", "writeText", [path, content, options || null]),
  readJSON: path => bridge.invoke("Storage", "readJSON", [path]),
  writeJSON: (path, value, options) => bridge.invoke("Storage", "writeJSON", [path, value, options || null]),
  readBinary: path => bridge.invoke("Storage", "readBinary", [path]),
  writeBinary: (path, value, options) => bridge.invoke("Storage", "writeBinary", [path, value, options || null]),
  exists: path => bridge.invoke("Storage", "exists", [path]),
  info: path => bridge.invoke("Storage", "info", [path]),
  list: path => bridge.invoke("Storage", "list", [path || "/data"]),
  createDirectory: path => bridge.invoke("Storage", "createDirectory", [path]),
  removePath: path => bridge.invoke("Storage", "removePath", [path]),
  move: (source, destination, options) => bridge.invoke("Storage", "move", [source, destination, options || null]),
  copy: (source, destination, options) => bridge.invoke("Storage", "copy", [source, destination, options || null]),
  temporaryFile: extension => bridge.invoke("Storage", "temporaryFile", [extension || null]),
  cleanupTemporary: maxAgeMs => bridge.invoke("Storage", "cleanupTemporary", [maxAgeMs])
};
PokeToolRuntime.storage = Object.freeze(storage);
module.exports = PokeToolRuntime.storage;
