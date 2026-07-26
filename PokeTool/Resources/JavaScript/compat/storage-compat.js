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
    const value = await Native.Storage.get(key);
    return value === null && arguments.length > 1 ? defaultValue : value;
  },
  set: (key, value) => Native.Storage.set(key, value),
  remove: key => Native.Storage.remove(key),
  has: key => Native.Storage.contains(key),
  keys: prefix => Native.Storage.keys(prefix),
  clear: prefix => Native.Storage.clear(prefix),
  readText: path => Native.Storage.readText(path),
  writeText: (path, content, options) => Native.Storage.writeText(path, content, options || null),
  readJSON: path => Native.Storage.readJSON(path),
  writeJSON: (path, value, options) => Native.Storage.writeJSON(path, value, options || null),
  readBinary: path => Native.Storage.readBinary(path),
  writeBinary: (path, value, options) => Native.Storage.writeBinary(path, value, options || null),
  exists: path => Native.Storage.exists(path),
  info: path => Native.Storage.info(path),
  list: path => Native.Storage.list(path || "/data"),
  createDirectory: path => Native.Storage.createDirectory(path),
  removePath: path => Native.Storage.removePath(path),
  move: (source, destination, options) => Native.Storage.move(source, destination, options || null),
  copy: (source, destination, options) => Native.Storage.copy(source, destination, options || null),
  temporaryFile: extension => Native.Storage.temporaryFile(extension || null),
  cleanupTemporary: maxAgeMs => Native.Storage.cleanupTemporary(maxAgeMs)
};
PokeToolRuntime.storage = Object.freeze(storage);
module.exports = PokeToolRuntime.storage;
