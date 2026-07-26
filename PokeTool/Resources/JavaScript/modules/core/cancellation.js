"use strict";
const errors = require("./errors");
class CancellationToken {
  constructor() { this.cancelled = false; this.reason = null; }
  cancel(reason) {
    if (this.cancelled) return false;
    this.cancelled = true; this.reason = reason || "Cancelled"; return true;
  }
  throwIfCancelled() {
    if (this.cancelled) {
      throw errors.productError("TASK_CANCELLED", this.reason, {retryable:false});
    }
  }
}
module.exports = {CancellationToken};
