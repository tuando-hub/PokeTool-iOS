(function (global) {
  "use strict";

  const DEFAULT_TIMEOUT = 30000;
  const POLL_INTERVAL = 250;
  const MAX_TIMEOUT = 120000;

  function compatError(code, message, operation, cause, details) {
    const error = new Error(message);
    error.name = "BrowserCompatibilityError";
    error.code = code;
    error.operation = operation;
    error.retryable = code === "WAIT_TIMEOUT" || code === "RELOAD_RECOVERY_FAILED";
    error.details = details || {};
    error.causeCode = cause && cause.code ? cause.code : null;
    return error;
  }

  function timeoutValue(value, operation) {
    const timeout = value === undefined || value === null ? DEFAULT_TIMEOUT : Number(value);
    if (!Number.isFinite(timeout) || timeout < 100 || timeout > MAX_TIMEOUT) {
      throw compatError("INVALID_ARGUMENT", operation + " timeout must be 100...120000 ms.", operation);
    }
    return timeout;
  }

  function requireBrowser(browser, operation) {
    if (!browser || typeof browser !== "object" || typeof browser.readyState !== "function") {
      throw compatError("INVALID_ARGUMENT", operation + " requires a browser handle.", operation);
    }
    return browser;
  }

  function mapError(error, operation) {
    if (error && error.name === "BrowserCompatibilityError") return error;
    const code = error && error.code;
    if (code === "CANCELLED") {
      return compatError("OPERATION_CANCELLED", operation + " was cancelled.", operation, error);
    }
    if (code === "INVALID_SESSION" || code === "INVALID_STATE") {
      return compatError("BROWSER_DESTROYED", "Browser is no longer available.", operation, error);
    }
    if (code === "SELECTOR_INVALID") {
      return compatError("INVALID_SELECTOR", "CSS selector is invalid.", operation, error);
    }
    return error;
  }

  function delay(ms) {
    const value = Number(ms);
    if (!Number.isFinite(value) || value < 0 || value > MAX_TIMEOUT) {
      return Promise.reject(compatError("INVALID_ARGUMENT", "delay must be 0...120000 ms.", "delay"));
    }
    return Native.Browser.__delay(value).catch(function (error) {
      throw mapError(error, "delay");
    });
  }

  async function poll(operation, browser, timeout, check, timeoutCode, timeoutMessage) {
    requireBrowser(browser, operation);
    const limit = timeoutValue(timeout, operation);
    const started = Date.now();
    let lastValue;
    while (Date.now() - started < limit) {
      try {
        const result = await check();
        lastValue = result.value;
        if (result.done) return result.value;
      } catch (error) {
        throw mapError(error, operation);
      }
      const remaining = limit - (Date.now() - started);
      if (remaining <= 0) break;
      await delay(Math.min(POLL_INTERVAL, remaining));
    }
    throw compatError(
      timeoutCode || "WAIT_TIMEOUT",
      timeoutMessage || operation + " timed out.",
      operation, null, { timeoutMs: limit, lastValue: lastValue === undefined ? null : lastValue }
    );
  }

  function matcherFunction(matcher, operation) {
    if (typeof matcher === "string") {
      return function (value) { return String(value || "").includes(matcher); };
    }
    if (matcher instanceof RegExp) {
      return function (value) {
        matcher.lastIndex = 0;
        return matcher.test(String(value || ""));
      };
    }
    if (typeof matcher === "function") {
      return function (value) {
        try { return Boolean(matcher(value)); }
        catch (_error) {
          throw compatError("INVALID_MATCHER", operation + " predicate threw an exception.", operation);
        }
      };
    }
    throw compatError("INVALID_MATCHER", operation + " matcher must be string, RegExp, or predicate.", operation);
  }

  function waitPageReady(browser, timeout) {
    return poll("waitPageReady", browser, timeout, async function () {
      const state = await browser.readyState();
      return { done: state === "interactive" || state === "complete", value: state };
    });
  }

  function waitExists(browser, selector, timeout) {
    return poll("waitExists", browser, timeout, async function () {
      const exists = await browser.exists(selector);
      return { done: exists, value: exists };
    }, "ELEMENT_NOT_FOUND", "Element did not appear before timeout.");
  }

  function waitGone(browser, selector, timeout) {
    return poll("waitGone", browser, timeout, async function () {
      const exists = await browser.exists(selector);
      return { done: !exists, value: !exists };
    });
  }

  function waitVisible(browser, selector, timeout) {
    return poll("waitVisible", browser, timeout, async function () {
      const snapshot = await browser.query(selector, "visibility");
      if (snapshot && snapshot.error === "selector") {
        throw compatError("INVALID_SELECTOR", "CSS selector is invalid.", "waitVisible");
      }
      return {
        done: Boolean(snapshot && snapshot.visible && snapshot.width > 0 && snapshot.height > 0),
        value: snapshot || null
      };
    }, "ELEMENT_NOT_VISIBLE", "Element did not become visible before timeout.");
  }

  function waitText(browser, text, timeout) {
    if (typeof text !== "string") {
      return Promise.reject(compatError("INVALID_ARGUMENT", "waitText requires a string.", "waitText"));
    }
    return poll("waitText", browser, timeout, async function () {
      const content = await browser.text();
      return { done: content.includes(text), value: content.includes(text) };
    });
  }

  function waitURL(browser, matcher, timeout) {
    let matches;
    try { matches = matcherFunction(matcher, "waitURL"); }
    catch (error) { return Promise.reject(error); }
    return poll("waitURL", browser, timeout, async function () {
      const value = await browser.url();
      return { done: matches(value), value: value };
    });
  }

  function waitTitle(browser, matcher, timeout) {
    let matches;
    try { matches = matcherFunction(matcher, "waitTitle"); }
    catch (error) { return Promise.reject(error); }
    return poll("waitTitle", browser, timeout, async function () {
      const value = await browser.title();
      return { done: matches(value), value: value };
    });
  }

  async function tapButton(browser, selector) {
    requireBrowser(browser, "tapButton");
    if (!await browser.exists(selector)) {
      throw compatError("ELEMENT_NOT_FOUND", "Button element was not found.", "tapButton");
    }
    try { await browser._call("click", [selector, null]); }
    catch (error) { throw mapError(error, "tapButton"); }
    return { completed: true, selector: selector };
  }

  async function setValue(browser, selector, value) {
    requireBrowser(browser, "setValue");
    await browser._call("setValue", [selector, String(value), null]);
    return { completed: true };
  }

  async function clearValue(browser, selector) {
    requireBrowser(browser, "clearValue");
    await browser._call("clear", [selector]);
    return { completed: true };
  }

  async function selectValue(browser, selector, value) {
    requireBrowser(browser, "selectValue");
    await browser._call("selectValue", [selector, String(value)]);
    return { completed: true };
  }

  async function setChecked(browser, selector, checked) {
    requireBrowser(browser, "setChecked");
    await browser._call("setChecked", [selector, Boolean(checked)]);
    return { completed: true };
  }

  function evalJS(browser, source) {
    requireBrowser(browser, "evalJS");
    return browser.evaluate(source);
  }

  function getURL(browser) {
    requireBrowser(browser, "getURL");
    return browser.url();
  }

  function getTitle(browser) {
    requireBrowser(browser, "getTitle");
    return browser.title();
  }

  async function reloadOnce(browser, options) {
    requireBrowser(browser, "reloadOnce");
    const settings = options || {};
    const timeout = timeoutValue(settings.timeout, "reloadOnce");
    const check = async function () {
      if (typeof settings.check === "function") return Boolean(await settings.check(browser));
      if (settings.url !== undefined) return matcherFunction(settings.url, "reloadOnce")(await browser.url());
      if (settings.title !== undefined) return matcherFunction(settings.title, "reloadOnce")(await browser.title());
      return false;
    };
    if (await check()) return { reloaded: false, recovered: true };
    await browser.reload();
    try {
      await waitPageReady(browser, timeout);
      const recovered = settings.check || settings.url !== undefined || settings.title !== undefined
        ? await check() : true;
      if (!recovered) {
        throw compatError(
          "RELOAD_RECOVERY_FAILED", "Reload completed but recovery condition was not met.",
          "reloadOnce", null, { reloaded: true }
        );
      }
      return { reloaded: true, recovered: true };
    } catch (error) {
      if (error && error.code === "RELOAD_RECOVERY_FAILED") throw error;
      throw compatError(
        "RELOAD_RECOVERY_FAILED", "Single reload recovery failed.",
        "reloadOnce", mapError(error, "reloadOnce"), { reloaded: true }
      );
    }
  }

  async function safeDestroy(browser) {
    if (!browser || typeof browser.destroy !== "function") {
      return { destroyed: false, alreadyDestroyed: true };
    }
    try {
      const alreadyDestroyed = Boolean(browser._destroyed);
      await browser.destroy();
      return { destroyed: !alreadyDestroyed, alreadyDestroyed: alreadyDestroyed };
    } catch (error) {
      const mapped = mapError(error, "safeDestroy");
      if (mapped && mapped.code === "BROWSER_DESTROYED") {
        browser._destroyed = true;
        return { destroyed: false, alreadyDestroyed: true };
      }
      throw mapped;
    }
  }

  PokeToolRuntime.web = Object.freeze({
    version: "1.0.0",
    delay: delay,
    waitPageReady: waitPageReady,
    waitVisible: waitVisible,
    waitExists: waitExists,
    waitGone: waitGone,
    waitText: waitText,
    waitURL: waitURL,
    waitTitle: waitTitle,
    tapButton: tapButton,
    setValue: setValue,
    clearValue: clearValue,
    selectValue: selectValue,
    setChecked: setChecked,
    evalJS: evalJS,
    getURL: getURL,
    getTitle: getTitle,
    reloadOnce: reloadOnce,
    safeDestroy: safeDestroy
  });
})(this);
