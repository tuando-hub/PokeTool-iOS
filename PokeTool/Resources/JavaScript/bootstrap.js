(function (global) {
  "use strict";

  const nativeBrowser = Native.Browser;

  function structuredError(value) {
    if (value instanceof Error && value.code) return value;
    const source = value && typeof value === "object" ? value : {};
    const error = new Error(source.message || "Native browser operation failed.");
    error.name = source.name || "BrowserError";
    error.code = source.code || "INTERNAL_ERROR";
    error.operationId = source.operationId || null;
    error.browserId = source.browserId || null;
    error.operation = source.operation || null;
    error.retryable = Boolean(source.retryable);
    error.details = source.details || {};
    return error;
  }

  function invoke(method, args) {
    let payload;
    try {
      payload = JSON.stringify({ args: args }, function (_key, value) {
        if (typeof value === "bigint" || typeof value === "symbol" || typeof value === "function") {
          throw new TypeError("Unsupported bridge value");
        }
        if (typeof value === "number" && !Number.isFinite(value)) {
          throw new TypeError("Non-finite numbers are not supported");
        }
        return value === undefined ? null : value;
      });
    } catch (_error) {
      return Promise.reject(structuredError({
        name: "BridgeError", code: "INVALID_ARGUMENT",
        message: method + ": arguments must be finite, acyclic JSON values.",
        operation: method, retryable: false
      }));
    }
    try {
      const promise = nativeBrowser.invoke(payload === undefined ? method : method, payload);
      return Promise.resolve(promise).catch(function (error) { throw structuredError(error); });
    } catch (error) {
      return Promise.reject(structuredError(error));
    }
  }

  const methods = [
    "__delay",
    "create", "destroy", "load", "reload", "reloadFromOrigin", "stop", "back", "forward",
    "evaluate", "snapshot", "url", "title", "readyState", "html", "text",
    "exists", "count", "query", "click", "focus", "blur", "setValue", "type", "clear",
    "setChecked", "selectValue", "selectIndex", "submit", "scrollIntoView",
    "waitNavigation", "cookies", "importCookies", "clearCookies",
    "websiteData", "clearWebsiteData", "setUserAgent", "resetUserAgent", "viewport",
    "screenshot"
  ];

  methods.forEach(function (method) {
    nativeBrowser[method] = function () {
      return invoke(method, Array.prototype.slice.call(arguments));
    };
  });
  nativeBrowser.cancelOperation = function (operationId) {
    return Promise.resolve(nativeBrowser.cancel(operationId));
  };
  nativeBrowser.getVersion = function () { return nativeBrowser.version; };

  class BrowserHandle {
    constructor(browserId) {
      this._browserId = browserId;
      this._destroyed = false;
    }
    get browserId() { return this._browserId; }
    _call(method, args) {
      if (this._destroyed) {
        return Promise.reject(structuredError({
          name: "BrowserError", code: "INVALID_STATE",
          message: "Browser handle has been destroyed.", browserId: this._browserId,
          operation: method, retryable: false
        }));
      }
      return nativeBrowser[method].apply(nativeBrowser, [this._browserId].concat(args || []));
    }
    load(request) {
      return this._call("load", [typeof request === "string" ? { url: request } : request]);
    }
    reload() { return this._call("reload"); }
    reloadFromOrigin() { return this._call("reloadFromOrigin"); }
    stop() { return this._call("stop"); }
    back() { return this._call("back"); }
    forward() { return this._call("forward"); }
    evaluate(source, options) { return this._call("evaluate", [source, options || null]); }
    snapshot() { return this._call("snapshot"); }
    url() { return this._call("url"); }
    title() { return this._call("title"); }
    readyState() { return this._call("readyState"); }
    html() { return this._call("html"); }
    text() { return this._call("text"); }
    exists(selector) { return this._call("exists", [selector]); }
    count(selector) { return this._call("count", [selector]); }
    query(selector, property) { return this._call("query", [selector, property]); }
    click(selector, options) { return this._call("click", [selector, options || null]); }
    waitNavigation(condition, options) { return this._call("waitNavigation", [condition, options || null]); }
    cookies(filter) { return this._call("cookies", [filter || null]); }
    screenshot(options) { return this._call("screenshot", [options || null]); }
    async destroy() {
      if (this._destroyed) return;
      await nativeBrowser.destroy(this._browserId);
      this._destroyed = true;
    }
  }

  const runtime = {
    version: "0.1.0",
    phase: 7,
    healthCheck: function () {
      return {
        ok: true, runtime: "JavaScriptCore", phase: this.phase,
        version: this.version, browserBridge: nativeBrowser.version
      };
    },
    browser: {
      create: async function (options) {
        return new BrowserHandle(await nativeBrowser.create(options || null));
      },
      capabilities: function () { return nativeBrowser.capabilities(); },
      version: nativeBrowser.version
    }
  };

  global.PokeToolRuntime = runtime;
  runtime.environment = Object.freeze({
    engine: "JavaScriptCore",
    runtimeId: Native.Runtime.runtimeID
  });
  runtime.modules = global.__PokeToolModuleSystem.modules;
  require("/compat/browser-compat");
  require("/compat/infrastructure");
  module.exports = runtime;
})(this);
