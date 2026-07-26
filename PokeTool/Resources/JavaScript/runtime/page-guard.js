"use strict";

const web = require("/compat/browser-compat");
const MAX_HISTORY = 32;

function flowError(code, message, details, cause) {
  const error = new Error(message);
  error.name = "FlowError";
  error.code = code;
  error.retryable = [
    "PAGE_VERIFICATION_TIMEOUT", "TRANSITION_NOT_OBSERVED",
    "WAIT_TIMEOUT", "ELEMENT_NOT_VISIBLE"
  ].includes(code);
  error.details = details || {};
  error.causeCode = cause && cause.code || null;
  return error;
}

function validateDescriptor(descriptor) {
  if (!descriptor || typeof descriptor !== "object" ||
      typeof descriptor.name !== "string" || !descriptor.name) {
    throw flowError("FLOW_PRECONDITION_FAILED", "Page descriptor requires a name.");
  }
  const signalCount = ["url", "title", "selectors", "text", "readyState", "customPredicate"]
    .filter(key => descriptor[key] !== undefined).length;
  if (!signalCount) {
    throw flowError("FLOW_PRECONDITION_FAILED", "Page descriptor requires at least one signal.");
  }
  if (descriptor.customPredicate !== undefined && typeof descriptor.customPredicate !== "function") {
    throw flowError("FLOW_PRECONDITION_FAILED", "customPredicate must be a JavaScript function.");
  }
  return descriptor;
}

function matchValue(value, matcher, kind) {
  if (matcher === undefined || matcher === null) return true;
  const input = String(value || "");
  if (typeof matcher === "string") return input.includes(matcher);
  if (matcher instanceof RegExp) { matcher.lastIndex = 0; return matcher.test(input); }
  if (typeof matcher === "function") return Boolean(matcher(input));
  if (typeof matcher !== "object") throw flowError("FLOW_PRECONDITION_FAILED", "Invalid " + kind + " matcher.");
  switch (matcher.type) {
    case "exact": return input === String(matcher.value);
    case "contains":
    case "includes": return input.includes(String(matcher.value));
    case "startsWith": return input.startsWith(String(matcher.value));
    case "includesAny": return (matcher.values || []).some(value => input.includes(String(value)));
    case "regex": {
      const regex = new RegExp(matcher.value, matcher.flags || "");
      return regex.test(input);
    }
    case "predicate":
      if (typeof matcher.predicate !== "function") throw flowError("FLOW_PRECONDITION_FAILED", "Predicate is invalid.");
      return Boolean(matcher.predicate(input));
    default: throw flowError("FLOW_PRECONDITION_FAILED", "Unsupported " + kind + " matcher.");
  }
}

async function selectorSignal(browser, item) {
  const selector = typeof item === "string" ? item : item.selector;
  const state = typeof item === "string" ? "exists" : item.state || "exists";
  if (!selector) throw flowError("FLOW_PRECONDITION_FAILED", "Selector signal is invalid.");
  if (state === "visible") {
    try {
      const snapshot = await browser.query(selector, "visibility");
      return Boolean(snapshot && snapshot.visible && snapshot.width > 0 && snapshot.height > 0);
    } catch (error) {
      if (["ELEMENT_NOT_FOUND","SELECTOR_NOT_FOUND"].includes(error && error.code)) return false;
      throw error;
    }
  }
  const exists = await browser.exists(selector);
  if (state === "gone") return !exists;
  return exists;
}

function redactExcerpt(text) {
  return String(text || "")
    .replace(/(password|passwd|token|secret|otp|authorization|card|cvv)\s*[:=]\s*\S+/gi, "$1=<redacted>")
    .slice(0, 1000);
}

async function inspect(browser, descriptor) {
  descriptor = validateDescriptor(descriptor);
  const started = performance.now();
  const snapshot = {
    url: await browser.url(),
    title: await browser.title(),
    readyState: await browser.readyState()
  };
  const text = descriptor.text !== undefined || descriptor.captureText === true
    ? await browser.text() : "";
  const signals = [];
  function add(name, matched, required) {
    signals.push({name:name, matched:Boolean(matched), required:required !== false});
  }
  if (descriptor.url !== undefined) add("url", matchValue(snapshot.url, descriptor.url, "URL"), true);
  if (descriptor.title !== undefined) add("title", matchValue(snapshot.title, descriptor.title, "title"), true);
  if (descriptor.readyState !== undefined) {
    const states = Array.isArray(descriptor.readyState) ? descriptor.readyState : [descriptor.readyState];
    add("readyState", states.includes(snapshot.readyState), true);
  }
  const selectors = descriptor.selectors || [];
  for (let index = 0; index < selectors.length; index += 1) {
    const item = selectors[index];
    add(
      "selector:" + (item.name || item.selector || item),
      await selectorSignal(browser, item),
      typeof item === "object" ? item.required !== false : true
    );
  }
  if (descriptor.text !== undefined) {
    const rule = descriptor.text;
    let matched = true;
    if (typeof rule === "string") matched = text.includes(rule);
    else {
      if (rule.includes !== undefined) matched = matched && text.includes(String(rule.includes));
      if (rule.includesAny) matched = matched && rule.includesAny.some(value => text.includes(String(value)));
      if (rule.excludes !== undefined) {
        const excluded = Array.isArray(rule.excludes) ? rule.excludes : [rule.excludes];
        matched = matched && excluded.every(value => !text.includes(String(value)));
      }
    }
    add("text", matched, true);
  }
  if (descriptor.customPredicate) {
    add("custom", await descriptor.customPredicate({
      browser:browser, url:snapshot.url, title:snapshot.title,
      readyState:snapshot.readyState, text:text
    }), descriptor.customRequired !== false);
  }

  const required = signals.filter(signal => signal.required);
  const optional = signals.filter(signal => !signal.required);
  const matchedCount = signals.filter(signal => signal.matched).length;
  const policy = descriptor.confidencePolicy || {type:"allRequired"};
  let ok;
  switch (policy.type || policy) {
    case "requiredAndOneOptional":
      ok = required.every(signal => signal.matched) && optional.some(signal => signal.matched);
      break;
    case "minimumMatches":
      ok = matchedCount >= Number(policy.minimum || policy.value || 1);
      break;
    case "custom":
      if (typeof policy.predicate !== "function") throw flowError("FLOW_PRECONDITION_FAILED", "Confidence predicate is invalid.");
      ok = Boolean(policy.predicate(signals));
      break;
    default: ok = required.every(signal => signal.matched);
  }
  return {
    ok:ok, pageName:descriptor.name, url:snapshot.url, title:snapshot.title,
    readyState:snapshot.readyState,
    matchedSignals:signals.filter(signal => signal.matched).map(signal => signal.name),
    missingSignals:signals.filter(signal => !signal.matched && signal.required).map(signal => signal.name),
    conflictingSignals:signals.filter(signal => !signal.matched && !signal.required).map(signal => signal.name),
    elapsedMs:performance.now() - started,
    snapshot:{
      url:snapshot.url, title:snapshot.title, readyState:snapshot.readyState,
      textExcerpt:descriptor.sensitive ? null : redactExcerpt(text)
    }
  };
}

async function waitFor(browser, descriptor, options) {
  const settings = options || {};
  const timeout = Math.min(Math.max(Number(settings.timeoutMs || 30000), 100), 120000);
  const interval = Math.min(Math.max(Number(settings.pollIntervalMs || 250), 100), 2000);
  const started = performance.now();
  let last;
  while (performance.now() - started < timeout) {
    if (settings.cancellationToken) settings.cancellationToken.throwIfCancelled();
    try {
      last = await inspect(browser, descriptor);
      if (last.ok) return last;
    } catch (error) {
      if (["INVALID_SESSION", "BROWSER_DESTROYED", "OPERATION_CANCELLED", "TASK_CANCELLED"].includes(error.code)) {
        throw error;
      }
      if (error.code === "FLOW_PRECONDITION_FAILED") throw error;
    }
    await web.delay(Math.min(interval, timeout - (performance.now() - started)));
  }
  throw flowError(
    "PAGE_VERIFICATION_TIMEOUT", "Expected page was not verified before timeout.",
    {pageName:descriptor.name, result:last, elapsedMs:performance.now() - started}
  );
}

async function assertPage(browser, descriptor, options) {
  const result = await waitFor(browser, descriptor, options);
  if (!result.ok) throw flowError("PAGE_MISMATCH", "Current page does not match descriptor.", result);
  return result;
}

async function describeCurrent(browser) {
  return {
    url:await browser.url(), title:await browser.title(),
    readyState:await browser.readyState()
  };
}

async function captureMismatch(browser, expected, options) {
  const result = await inspect(browser, Object.assign({}, expected, {captureText:true}));
  const output = {expected:expected.name, result:result, screenshot:null};
  if (options && options.screenshot && !options.sensitive && browser.screenshot) {
    try { output.screenshot = await browser.screenshot({format:"png", capture:"viewport", filenameHint:"flow-mismatch"}); }
    catch (_) {}
  }
  return output;
}

module.exports = {
  version:"1.0.0", inspect, matches:async (browser, descriptor) => (await inspect(browser, descriptor)).ok,
  waitFor, assert:assertPage, describeCurrent, captureMismatch,
  validateDescriptor, flowError, MAX_HISTORY
};
