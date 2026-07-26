"use strict";
const storage = require("./storage-compat");
const secrets = require("./secrets-compat");
const network = require("./network-compat");
const system = require("./system-compat");
const device = require("./device-compat");
const notification = require("./notification-compat");
const events = require("./events-compat");

const infrastructure = Object.freeze({
  version:"1.0.0", storage, secrets, network, system, device, notification, events,
  capabilities: function () {
    return {
      storage:storage.capabilities(), keychain:secrets.capabilities(),
      network:network.capabilities(), system:system.capabilities(),
      device:device.capabilities(), notification:notification.capabilities(),
      events:events.capabilities()
    };
  }
});
PokeToolRuntime.infrastructure = infrastructure;
module.exports = infrastructure;
