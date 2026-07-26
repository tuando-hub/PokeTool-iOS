"use strict";
function task(task, status, value, error, durationMs) {
  return {
    taskId:task.id, mode:task.mode, index:task.index, status:status,
    value:value === undefined ? null : value,
    error:error ? {code:error.code || "INTERNAL_FLOW_ERROR", message:error.message, retryable:Boolean(error.retryable)} : null,
    durationMs:durationMs
  };
}
function summary(results, durationMs) {
  const count = status => results.filter(result => result.status === status).length;
  return {
    total:results.length, succeeded:count("succeeded"), failed:count("failed"),
    cancelled:count("cancelled"), skipped:count("skipped"),
    durationMs:durationMs, results:results.slice()
  };
}
module.exports = {task, summary};
