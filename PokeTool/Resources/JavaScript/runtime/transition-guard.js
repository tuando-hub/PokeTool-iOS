"use strict";
const PageGuard = require("./page-guard");
const web = require("/compat/browser-compat");

function policy(value) {
  const source = value || {};
  return {
    maxAttempts:Math.min(Math.max(Number(source.maxAttempts || 1), 1), 5),
    delayMs:Math.min(Math.max(Number(source.delayMs || 250), 0), 10000),
    backoff:Math.min(Math.max(Number(source.backoff || 1), 1), 3),
    retryOn:source.retryOn || [
      "PAGE_VERIFICATION_TIMEOUT", "TRANSITION_NOT_OBSERVED",
      "WAIT_TIMEOUT", "ELEMENT_NOT_VISIBLE"
    ]
  };
}

async function recover(options, attempt, deadline) {
  const recovery = options.recoveryPolicy || {type:"none"};
  if (recovery === "none" || recovery.type === "none") return false;
  if (performance.now() >= deadline) return false;
  switch (recovery.type || recovery) {
    case "waitAgain": await web.delay(Math.min(recovery.delayMs || 500, deadline - performance.now())); return true;
    case "reloadOnce":
      if (attempt > 1) return false;
      await web.reloadOnce(options.browser, {timeout:Math.max(100, deadline - performance.now())});
      return true;
    case "goBackOnce":
      if (attempt > 1) return false;
      await options.browser.back(); return true;
    case "navigateToKnownURL":
      if (attempt > 1 || typeof recovery.url !== "string") return false;
      await options.browser.load(recovery.url); return true;
    case "custom":
      if (typeof recovery.perform !== "function") return false;
      await recovery.perform(options.browser, attempt); return true;
    default: throw PageGuard.flowError("FLOW_PRECONDITION_FAILED", "Unknown recovery policy.");
  }
}

async function observe(browser, descriptors, deadline, token, history) {
  let last;
  while (performance.now() < deadline) {
    token && token.throwIfCancelled();
    const current = await PageGuard.describeCurrent(browser);
    const previous = history[history.length - 1];
    if (!previous || previous.url !== current.url || previous.title !== current.title) {
      history.push({url:current.url, title:current.title, timestamp:Date.now()});
      if (history.length > PageGuard.MAX_HISTORY) history.shift();
    }
    for (const descriptor of descriptors) {
      const result = await PageGuard.inspect(browser, descriptor);
      if (result.ok) return {descriptor:descriptor, result:result};
      last = result;
    }
    await web.delay(Math.min(250, Math.max(4, deadline - performance.now())));
  }
  throw PageGuard.flowError("TRANSITION_NOT_OBSERVED", "Destination page was not observed.", {
    history:history, last:last
  });
}

async function perform(options) {
  if (!options || !options.browser || typeof options.action !== "function" || !options.to) {
    throw PageGuard.flowError("FLOW_PRECONDITION_FAILED", "Transition configuration is invalid.");
  }
  const retry = policy(options.retryPolicy);
  const timeout = Math.min(Math.max(Number(options.timeoutMs || 30000), 100), 120000);
  const deadline = performance.now() + timeout;
  const history = [];
  let lastError;
  for (let attempt = 1; attempt <= retry.maxAttempts; attempt += 1) {
    options.cancellationToken && options.cancellationToken.throwIfCancelled();
    if (options.from) {
      await PageGuard.assert(options.browser, options.from, {
        timeoutMs:Math.min(3000, Math.max(100, deadline - performance.now())),
        cancellationToken:options.cancellationToken
      });
    }
    try {
      await options.action({attempt:attempt, browser:options.browser});
      const observed = await observe(
        options.browser, [options.to].concat(options.allowIntermediate || []),
        deadline, options.cancellationToken, history
      );
      if (observed.descriptor === options.to) {
        return {
          ok:true, name:options.name || "transition", attempt:attempt,
          destination:observed.result, history:history,
          elapsedMs:timeout - Math.max(0, deadline - performance.now())
        };
      }
      const destination = await PageGuard.waitFor(options.browser, options.to, {
        timeoutMs:Math.max(100, deadline - performance.now()),
        cancellationToken:options.cancellationToken
      });
      return {ok:true, name:options.name || "transition", attempt, destination, history};
    } catch (error) {
      lastError = error;
      if (error.code === "TASK_CANCELLED" || error.code === "RUNTIME_STOPPED") throw error;
      const retryable = retry.retryOn.includes(error.code);
      if (!retryable || attempt >= retry.maxAttempts || performance.now() >= deadline) break;
      if (options.onRetry) await options.onRetry({attempt:attempt, error:error});
      await recover(options, attempt, deadline);
      await web.delay(Math.min(retry.delayMs * Math.pow(retry.backoff, attempt - 1), deadline - performance.now()));
    }
  }
  throw PageGuard.flowError("RETRY_EXHAUSTED", "Transition retry policy was exhausted.", {
    history:history, lastCode:lastError && lastError.code
  }, lastError);
}

module.exports = {version:"1.0.0", perform, policy};
