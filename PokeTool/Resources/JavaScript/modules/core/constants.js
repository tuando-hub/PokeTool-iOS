"use strict";
module.exports = Object.freeze({
  runtimeStatus:["idle","ready","running","stopping","stopped","failed"],
  taskStatus:["pending","running","succeeded","failed","cancelled","skipped"],
  fatalCodes:["RUNTIME_STOPPED","DEPENDENCY_UNAVAILABLE","INTERNAL_FLOW_ERROR"],
  errorCodes:[
    "FLOW_PRECONDITION_FAILED","PAGE_MISMATCH","PAGE_VERIFICATION_TIMEOUT",
    "TRANSITION_NOT_OBSERVED","UNEXPECTED_PAGE","ACTION_FAILED","RECOVERY_FAILED",
    "RETRY_EXHAUSTED","TASK_CANCELLED","TASK_TIMEOUT","RUNTIME_STOPPED",
    "INVALID_TASK","DEPENDENCY_UNAVAILABLE","INTERNAL_FLOW_ERROR"
  ]
});
