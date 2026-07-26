(function (global) {
  "use strict";

  const VERSION = "1.0.0";
  const nativeRuntime = Native.Runtime;
  const cache = Object.create(null);
  const graph = Object.create(null);
  const failures = [];
  const loadOrder = [];
  let totalSourceBytes = 0;
  let stopped = false;
  const limits = Object.freeze({
    maximumModules: 512,
    maximumSourceBytes: 1048576,
    maximumTotalSourceBytes: 16777216,
    maximumDependencyDepth: 128,
    maximumPathLength: 512,
    maximumActiveTimers: 128,
    minimumTimerDelayMilliseconds: 4,
    maximumTimerDelayMilliseconds: 120000,
    maximumConsolePayloadBytes: 16384
  });

  function parseNativeResult(json) {
    let result;
    try { result = JSON.parse(json); }
    catch (_) { throw moduleError("INTERNAL_MODULE_ERROR", "Native module response is invalid.", null, null, "load"); }
    if (!result.ok) {
      const source = result.error || {};
      throw moduleError(
        source.code || "INTERNAL_MODULE_ERROR", source.message || "Module operation failed.",
        source.requestedId, source.canonicalId, source.phase || "load", source.parentModuleId
      );
    }
    return result.value;
  }

  function moduleError(code, message, requestedId, canonicalId, phase, parentModuleId, cause) {
    const error = new Error(message);
    error.name = "RuntimeModuleError";
    error.code = code;
    error.requestedId = requestedId || null;
    error.canonicalId = canonicalId || null;
    error.parentModuleId = parentModuleId || null;
    error.phase = phase;
    error.retryable = false;
    if (cause && cause.stack) error.moduleStack = String(cause.stack).slice(0, 4096);
    return error;
  }

  function safeConsoleValue(value, seen, depth) {
    if (value === null || value === undefined) return String(value);
    if (typeof value === "string") return value;
    if (typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") return String(value);
    if (typeof value === "function") return "[Function]";
    if (depth > 4) return "[MaxDepth]";
    if (seen.indexOf(value) >= 0) return "[Circular]";
    seen.push(value);
    let output;
    try {
      if (Array.isArray(value)) {
        output = "[" + value.slice(0, 50).map(v => safeConsoleValue(v, seen, depth + 1)).join(", ") + "]";
      } else {
        output = "{" + Object.keys(value).slice(0, 50).map(function (key) {
          return key + ": " + safeConsoleValue(value[key], seen, depth + 1);
        }).join(", ") + "}";
      }
    } catch (_) { output = "[Unserializable]"; }
    seen.pop();
    return output;
  }

  function writeConsole(level, args) {
    let message = Array.prototype.map.call(args, value => safeConsoleValue(value, [], 0)).join(" ");
    if (message.length > limits.maximumConsolePayloadBytes) {
      message = message.slice(0, limits.maximumConsolePayloadBytes) + " [truncated]";
    }
    try { Native.Logger[level](message, { runtimeId: nativeRuntime.runtimeID, moduleId: currentModuleID || "/" }); }
    catch (_) {}
  }

  const consoleAPI = Object.freeze({
    debug: function () { writeConsole("debug", arguments); },
    log: function () { writeConsole("info", arguments); },
    info: function () { writeConsole("info", arguments); },
    warn: function () { writeConsole("warning", arguments); },
    error: function () { writeConsole("error", arguments); }
  });

  let currentModuleID = null;

  function resolve(request, parentID) {
    if (stopped) throw moduleError("MODULE_RUNTIME_STOPPED", "Runtime has stopped.", request, null, "resolve", parentID);
    return parseNativeResult(nativeRuntime.resolveModule(request, parentID || null)).canonicalId;
  }

  function addEdge(parentID, childID) {
    if (!parentID) return;
    const parent = graph[parentID];
    if (parent && parent.children.indexOf(childID) < 0) parent.children.push(childID);
    const child = graph[childID];
    if (child && child.parents.indexOf(parentID) < 0) child.parents.push(parentID);
    if (cache[parentID] && cache[parentID].children.indexOf(childID) < 0) {
      cache[parentID].children.push(childID);
    }
  }

  function requireFrom(request, parentID, depth) {
    if (depth > limits.maximumDependencyDepth) {
      throw moduleError("RESOURCE_LIMIT_EXCEEDED", "Maximum dependency depth exceeded.", request, null, "resolve", parentID);
    }
    const canonicalID = resolve(request, parentID);
    if (cache[canonicalID]) {
      addEdge(parentID, canonicalID);
      return cache[canonicalID].exports;
    }
    if (Object.keys(cache).length >= limits.maximumModules) {
      throw moduleError("RESOURCE_LIMIT_EXCEEDED", "Maximum module count exceeded.", request, canonicalID, "load", parentID);
    }

    const sourceRecord = parseNativeResult(nativeRuntime.loadModuleSource(canonicalID));
    if (totalSourceBytes + sourceRecord.byteCount > limits.maximumTotalSourceBytes) {
      throw moduleError("RESOURCE_LIMIT_EXCEEDED", "Total module source limit exceeded.", request, canonicalID, "load", parentID);
    }
    const module = {
      id: canonicalID, filename: sourceRecord.filename, dirname: sourceRecord.dirname,
      exports: {}, loaded: false, loading: true, parent: parentID || null, children: []
    };
    cache[canonicalID] = module;
    graph[canonicalID] = {
      id: canonicalID, parents: [], children: [], state: "loading",
      loadOrder: loadOrder.length, durationMs: 0, sourceBytes: sourceRecord.byteCount,
      circular: false
    };
    loadOrder.push(canonicalID);
    totalSourceBytes += sourceRecord.byteCount;
    addEdge(parentID, canonicalID);
    const started = nativeRuntime.monotonicMilliseconds();
    try {
      const localRequire = function (childRequest) {
        const childID = resolve(childRequest, canonicalID);
        if (cache[childID] && cache[childID].loading) graph[childID].circular = true;
        return requireFrom(childRequest, canonicalID, depth + 1);
      };
      localRequire.resolve = function (childRequest) { return resolve(childRequest, canonicalID); };
      const wrapped = "(function(exports,require,module,__filename,__dirname,global,console,PokeToolRuntime,Native){\\n" +
        sourceRecord.source + "\\n})\\n//# sourceURL=poketool://" + canonicalID.slice(1);
      const factory = global.eval(wrapped);
      if (typeof factory !== "function") {
        throw moduleError("MODULE_COMPILE_FAILED", "Module wrapper did not compile.", request, canonicalID, "compile", parentID);
      }
      const previous = currentModuleID;
      currentModuleID = canonicalID;
      try {
        factory(module.exports, localRequire, module, module.filename, module.dirname,
                global, consoleAPI, global.PokeToolRuntime, Native);
      } finally { currentModuleID = previous; }
      module.loaded = true;
      module.loading = false;
      graph[canonicalID].state = "loaded";
      graph[canonicalID].durationMs = nativeRuntime.monotonicMilliseconds() - started;
      return module.exports;
    } catch (cause) {
      delete cache[canonicalID];
      graph[canonicalID].state = "failed";
      graph[canonicalID].durationMs = nativeRuntime.monotonicMilliseconds() - started;
      totalSourceBytes -= sourceRecord.byteCount;
      const error = cause && cause.name === "RuntimeModuleError" ? cause :
        moduleError("MODULE_EXECUTION_FAILED", "Module execution failed.", request, canonicalID, "execute", parentID, cause);
      failures.push({ id: canonicalID, code: error.code, phase: error.phase, message: error.message });
      throw error;
    }
  }

  function rootRequire(request) { return requireFrom(request, null, 0); }
  rootRequire.resolve = function (request) { return resolve(request, null); };

  function snapshot() {
    return {
      version: VERSION, runtimeId: nativeRuntime.runtimeID, stopped: stopped,
      loaded: Object.keys(cache).filter(id => cache[id].loaded),
      loading: Object.keys(cache).filter(id => cache[id].loading),
      failed: failures.slice(), cacheCount: Object.keys(cache).length,
      loadOrder: loadOrder.slice(), graph: JSON.parse(JSON.stringify(graph)),
      circularDependencies: Object.keys(graph).filter(id => graph[id].circular),
      activeTimerCount: nativeRuntime.activeTimerCount(),
      totalSourceBytes: totalSourceBytes, limits: limits
    };
  }

  function clearModule(id, reverse) {
    if (!global.__POKETOOL_DEBUG__) {
      throw moduleError("UNSUPPORTED_MODULE_FEATURE", "Module cache mutation is Debug-only.", id, null, "cache");
    }
    const canonicalID = resolve(id, null);
    if (cache[canonicalID] && cache[canonicalID].loading) {
      throw moduleError("MODULE_CACHE_ERROR", "Cannot clear a module while it is loading.", id, canonicalID, "cache");
    }
    const targets = [canonicalID];
    if (reverse && graph[canonicalID]) targets.push.apply(targets, graph[canonicalID].parents);
    targets.forEach(function (target) {
      if (cache[target]) totalSourceBytes -= graph[target].sourceBytes || 0;
      delete cache[target];
      if (graph[target]) graph[target].state = "cleared";
    });
    return targets;
  }

  const modulesAPI = Object.freeze({
    version: VERSION,
    capabilities: function () {
      return {
        commonJS: true, relativeRequire: true, absoluteLogicalRequire: true,
        cache: true, circularDependencies: true, dependencyGraph: true, timers: true,
        hotReload: global.__POKETOOL_DEBUG__ ? "debugOnly" : false,
        nodeModules: false, npm: false, esModules: false, remoteModules: false
      };
    },
    list: function () { return Object.keys(cache); },
    isLoaded: function (id) {
      const canonicalID = resolve(id, null);
      return Boolean(cache[canonicalID] && cache[canonicalID].loaded);
    },
    graph: snapshot,
    clear: clearModule,
    reload: function (id, reverse) { clearModule(id, reverse); return rootRequire(id); }
  });

  function setTimer(callback, delay, repeats) {
    if (typeof callback !== "function") throw new TypeError("Timer callback must be a function.");
    const id = nativeRuntime.scheduleTimer(callback, Number(delay) || 0, repeats);
    if (!id) throw moduleError("RESOURCE_LIMIT_EXCEEDED", "Unable to schedule timer.", null, null, "timer");
    return id;
  }

  global.global = global;
  if (typeof global.globalThis === "undefined") global.globalThis = global;
  global.console = consoleAPI;
  global.require = rootRequire;
  global.setTimeout = function (callback, delay) { return setTimer(callback, delay, false); };
  global.clearTimeout = function (id) { nativeRuntime.clearTimer(Number(id)); };
  global.setInterval = function (callback, delay) { return setTimer(callback, delay, true); };
  global.clearInterval = global.clearTimeout;
  global.performance = Object.freeze({ now: function () { return nativeRuntime.monotonicMilliseconds(); } });
  global.__PokeToolModuleSystem = {
    modules: modulesAPI,
    diagnostics: snapshot,
    stop: function () {
      stopped = true;
      Object.keys(cache).forEach(id => delete cache[id]);
      Object.keys(graph).forEach(id => delete graph[id]);
      totalSourceBytes = 0;
    }
  };
})(this);
