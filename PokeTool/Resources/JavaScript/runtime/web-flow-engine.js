"use strict";
const PageGuard = require("./page-guard");
const TransitionGuard = require("./transition-guard");
const UnexpectedPages = require("./unexpected-pages");

function checkpoint(context, step, state) {
  return {
    flowId:context.flowId, taskId:context.taskId, stepId:step.id,
    state:state, browserSessionId:step.sensitive ? null : context.browserId || null,
    timestamp:Date.now(), safePayload:step.checkpoint && step.checkpoint.safePayload || {}
  };
}

async function run(context, steps) {
  if (!context || !context.browser || !Array.isArray(steps)) {
    throw PageGuard.flowError("FLOW_PRECONDITION_FAILED", "Flow context or steps are invalid.");
  }
  const history = [];
  for (const step of steps) {
    context.cancellationToken && context.cancellationToken.throwIfCancelled();
    const record = {
      id:step.id, name:step.name, state:"CheckingPrecondition",
      startedAt:Date.now(), attempt:0, checkpoint:null
    };
    history.push(record);
    context.emit && await context.emit("flow.step.started", {stepId:step.id, name:step.name});
    try {
      if (step.pageBefore) {
        record.precondition = await PageGuard.assert(context.browser, step.pageBefore, {
          timeoutMs:Math.min(step.timeoutMs || 30000, 5000),
          cancellationToken:context.cancellationToken
        });
      }
      record.state = "RunningAction";
      const transition = await TransitionGuard.perform({
        name:step.name, browser:context.browser, from:null,
        action:step.action, to:step.pageAfter,
        allowIntermediate:step.allowIntermediate,
        timeoutMs:step.timeoutMs, retryPolicy:step.retryPolicy,
        recoveryPolicy:step.recoveryPolicy,
        cancellationToken:context.cancellationToken,
        detectUnexpected:browser => UnexpectedPages.detect(browser),
        onRetry:async info => {
          record.state = "Retrying"; record.attempt = info.attempt;
          context.emit && await context.emit("flow.step.retrying", {
            stepId:step.id, attempt:info.attempt, code:info.error.code
          });
        }
      });
      record.state = "Succeeded";
      record.transition = transition;
      record.checkpoint = checkpoint(context, step, "succeeded");
      record.durationMs = Date.now() - record.startedAt;
      context.emit && await context.emit("flow.step.completed", {
        stepId:step.id, durationMs:record.durationMs
      });
    } catch (error) {
      const unexpected = error.code === "UNEXPECTED_PAGE"
        ? null : await UnexpectedPages.detect(context.browser);
      if (unexpected) {
        error = PageGuard.flowError("UNEXPECTED_PAGE", "Unexpected page detected.", {
          state:unexpected.code, descriptor:unexpected.descriptor.name
        }, error);
      }
      record.state = error.code === "TASK_CANCELLED" ? "Cancelled" : "Failed";
      record.error = {code:error.code || "INTERNAL_FLOW_ERROR", message:error.message};
      record.durationMs = Date.now() - record.startedAt;
      context.emit && await context.emit("flow.step.failed", {
        stepId:step.id, code:record.error.code
      });
      throw Object.assign(error, {flowHistory:history});
    }
  }
  return {ok:true, flowId:context.flowId, taskId:context.taskId, steps:history};
}

module.exports = {
  version:"1.0.0", run, PageGuard, TransitionGuard, UnexpectedPages,
  capabilities:{
    multiSignalVerification:true, transitionVerification:true,
    boundedRetry:true, boundedRecovery:true, checkpoints:"foundation",
    captchaBypass:false
  }
};
