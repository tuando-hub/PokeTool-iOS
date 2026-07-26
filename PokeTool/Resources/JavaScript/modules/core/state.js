"use strict";
const initial = () => ({
  runtimeStatus:"ready", running:false, mode:null, taskId:null,
  accountIdentifier:null, step:null, status:"idle", index:0, total:0,
  startedAt:null, elapsedMs:0, progress:0, lastError:null,
  correlationId:null
});
class ProductState {
  constructor(events) { this.events = events; this.value = initial(); }
  snapshot() {
    const value = Object.assign({}, this.value);
    if (value.startedAt) value.elapsedMs = Date.now() - value.startedAt;
    return value;
  }
  async update(patch) {
    if (!patch || typeof patch !== "object") throw new TypeError("State patch is invalid.");
    const next = Object.assign({}, this.value, patch);
    if (next.total < 0 || next.index < 0 || next.index > next.total) throw new RangeError("State index/total is invalid.");
    if (!Number.isFinite(next.progress) || next.progress < 0 || next.progress > 1) throw new RangeError("State progress is invalid.");
    this.value = next;
    if (this.events) await this.events.emit("runtime.state.changed", this.snapshot());
    return this.snapshot();
  }
  reset() { this.value = initial(); return this.snapshot(); }
}
module.exports = {ProductState, initial};
