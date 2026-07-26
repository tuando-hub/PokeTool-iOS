"use strict";
const bridge = require("./bridge-utils");
bridge.bind("Notification", [
  "authorizationStatus","requestAuthorization","schedule","cancel","cancelAll",
  "pending","delivered","removeDelivered","removeAllDelivered"
]);
PokeToolRuntime.notification = Object.freeze({
  version: Native.Notification.version,
  capabilities: () => Native.Notification.capabilities(),
  status: () => Native.Notification.authorizationStatus(),
  requestPermission: options => Native.Notification.requestAuthorization(options || null),
  schedule: options => Native.Notification.schedule(options),
  cancel: id => Native.Notification.cancel(id),
  cancelAll: () => Native.Notification.cancelAll(),
  pending: () => Native.Notification.pending(),
  delivered: () => Native.Notification.delivered()
});
module.exports = PokeToolRuntime.notification;
