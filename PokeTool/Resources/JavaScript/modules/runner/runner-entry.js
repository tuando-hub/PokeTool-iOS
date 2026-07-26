"use strict";
const core = require("../core/core-entry");
const web = require("/compat/browser-compat");

let configuration = {
  stopOnError:false, continueOnRetryableFailure:true,
  taskTimeoutMs:600000, delayBetweenTasksMs:0
};
let running = false;
let currentTask = null;
let collected = [];
let token = null;

function configure(options) {
  if (running) throw core.errors.productError("INVALID_TASK", "Cannot configure a running runner.");
  const input = options || {};
  configuration = Object.assign({}, configuration, input);
  configuration.taskTimeoutMs = Math.min(Math.max(Number(configuration.taskTimeoutMs), 100), 900000);
  configuration.delayBetweenTasksMs = Math.min(Math.max(Number(configuration.delayBetweenTasksMs), 0), 10000);
  return Object.assign({}, configuration);
}

async function withTimeout(executor, task, context) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(core.errors.productError(
      "TASK_TIMEOUT", "Task exceeded its timeout.", {taskId:task.id}
    )), configuration.taskTimeoutMs);
  });
  try { return await Promise.race([executor(task, context), timeout]); }
  finally { clearTimeout(timer); }
}

async function start(inputs, executor) {
  if (running) throw core.errors.productError("INVALID_TASK", "Runner is already active.");
  if (!Array.isArray(inputs) || typeof executor !== "function") {
    throw core.errors.productError("INVALID_TASK", "Runner requires tasks and an executor.");
  }
  running = true; collected = []; token = new core.cancellation.CancellationToken();
  const started = Date.now();
  await core.state.update({
    runtimeStatus:"running", running:true, total:inputs.length,
    index:0, progress:inputs.length ? 0 : 1, startedAt:started,
    correlationId:await PokeToolRuntime.system.uuid()
  });
  await PokeToolRuntime.events.emit("runner.started", {total:inputs.length});
  const visited = new Set();
  for (let index = 0; index < inputs.length; index += 1) {
    if (token.cancelled) break;
    visited.add(index);
    const task = await core.task.create(inputs[index], index, inputs.length);
    currentTask = task; task.status = "running";
    await core.state.update({
      taskId:task.id, mode:task.mode, index:index, step:null,
      status:"running", progress:inputs.length ? index / inputs.length : 1
    });
    await PokeToolRuntime.events.emit("runner.task.started", {taskId:task.id,index:index});
    const taskStarted = Date.now();
    try {
      const value = await withTimeout(executor, task, {
        cancellationToken:token,
        correlationId:core.current().correlationId,
        emit:PokeToolRuntime.events.emit
      });
      token.throwIfCancelled();
      task.status = "succeeded";
      collected.push(core.result.task(task, "succeeded", value, null, Date.now() - taskStarted));
      await PokeToolRuntime.events.emit("runner.task.completed", {taskId:task.id});
    } catch (rawError) {
      const error = core.errors.wrap(rawError, {taskId:task.id});
      const cancelled = error.code === "TASK_CANCELLED" || token.cancelled;
      task.status = cancelled ? "cancelled" : "failed";
      collected.push(core.result.task(task, task.status, null, error, Date.now() - taskStarted));
      await PokeToolRuntime.events.emit(
        cancelled ? "runner.stopped" : "runner.task.failed",
        {taskId:task.id, code:error.code}
      );
      if (cancelled || configuration.stopOnError ||
          (!error.retryable && core.constants.fatalCodes.includes(error.code))) break;
    }
    if (index + 1 < inputs.length && configuration.delayBetweenTasksMs > 0) {
      token.throwIfCancelled();
      await web.delay(configuration.delayBetweenTasksMs);
    }
  }
  if (token.cancelled && currentTask && !collected.some(item => item.taskId === currentTask.id)) {
    collected.push(core.result.task(currentTask, "cancelled", null, core.errors.productError(
      "TASK_CANCELLED", token.reason, {taskId:currentTask.id}
    ), 0));
  }
  let cancellationRecorded = collected.some(item => item.status === "cancelled");
  for (let index = 0; index < inputs.length; index += 1) {
    if (visited.has(index)) continue;
    const task = await core.task.create(inputs[index], index, inputs.length);
    if (token.cancelled && !cancellationRecorded) {
      collected.push(core.result.task(task, "cancelled", null, core.errors.productError(
        "TASK_CANCELLED", token.reason, {taskId:task.id}
      ), 0));
      cancellationRecorded = true;
    } else {
      collected.push(core.result.task(task, "skipped", null, null, 0));
    }
  }
  const output = core.result.summary(collected, Date.now() - started);
  running = false; currentTask = null;
  await core.state.update({
    runtimeStatus:"ready", running:false, taskId:null,
    status:output.cancelled ? "cancelled" : "completed",
    index:inputs.length, progress:1
  });
  return output;
}

function stop(reason) {
  if (!token) return false;
  return token.cancel(reason || "User requested stop.");
}
function reset() {
  if (running) throw core.errors.productError("INVALID_TASK", "Cannot reset active runner.");
  currentTask = null; collected = []; token = null; core.reset(); return true;
}
module.exports = {
  version:"1.0.0", configure, start, stop,
  isRunning:() => running, current:() => currentTask,
  results:() => collected.slice(), reset
};
