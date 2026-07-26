"use strict";
const bridge = require("./bridge-utils");
bridge.bind("Events", ["emit"]);
const subscriptions = Object.create(null);
let nextId = 1;

function validName(name) {
  return typeof name === "string" && /^(js|runtime|plugin)\.[A-Za-z0-9._-]+$/.test(name);
}
function on(name, handler) {
  if (!validName(name) || typeof handler !== "function") throw new TypeError("Invalid event subscription.");
  if (Object.keys(subscriptions).length >= 128) throw new Error("Event subscription limit reached.");
  const id = "subscription-" + nextId++;
  subscriptions[id] = {name:name, handler:handler};
  return id;
}
function off(id) {
  const existed = Boolean(subscriptions[id]);
  delete subscriptions[id];
  return existed;
}
async function emit(name, payload) {
  if (!validName(name)) throw Object.assign(new Error("Event name is forbidden."), {code:"EVENT_FORBIDDEN_NAME"});
  const event = await Native.Events.emit(name, payload === undefined ? null : payload);
  Object.keys(subscriptions).forEach(function (id) {
    const entry = subscriptions[id];
    if (entry.name === name) {
      try { entry.handler(payload, event); } catch (error) { console.error("Event handler failed", error); }
    }
  });
  return event;
}
function once(name, options) {
  const timeout = options && options.timeoutMs || 30000;
  return new Promise(function (resolve, reject) {
    let timer;
    const id = on(name, function (payload, event) {
      off(id); clearTimeout(timer); resolve({payload:payload,event:event});
    });
    timer = setTimeout(function () {
      off(id);
      reject(Object.assign(new Error("Event wait timed out."), {code:"EVENT_TIMEOUT"}));
    }, timeout);
  });
}
PokeToolRuntime.events = Object.freeze({
  version: Native.Events.version,
  capabilities: () => Native.Events.capabilities(),
  on:on, off:off, once:once,
  next:(filter, options) => once(typeof filter === "string" ? filter : filter.name, options),
  emit:emit
});
module.exports = PokeToolRuntime.events;
