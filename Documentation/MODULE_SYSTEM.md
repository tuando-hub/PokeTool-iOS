# JavaScript Runtime Module System

## Goal and scope

Phase 5 adds a per-runtime CommonJS module system so later phases can migrate JavaScript incrementally. It contains runtime primitives and neutral fixtures only. It does not include business logic, Node.js, npm, `node_modules`, ES Modules, filesystem access, or remote code.

The module API version is `1.0.0`: patch releases are compatible fixes, minor releases add compatible capabilities, and major releases may break the public contract. Callers should inspect `PokeToolRuntime.modules.capabilities()`.

## Architecture

```text
JavaScriptRuntime
    |
    +-- ModuleLoader
        +-- ModuleResolver
        +-- ModuleSourceProvider
        +-- ModuleCache
        +-- DependencyGraph
        +-- ExecutionContext
                |
                +-- JSContext
```

`JavaScriptModuleResolver` canonicalizes logical paths. `BundleJavaScriptModuleSourceProvider` reads only controlled application resources. `RuntimeBridgeNamespace` provides sources, a monotonic clock, and timer lifecycle. `runtime/module-loader.js` owns CommonJS execution, cache, and graph inside one JSContext.

## Resources and bootstrap

```text
Resources/JavaScript/
    bootstrap.js
    runtime/module-loader.js
    compat/browser-compat.js
    modules/fixtures/
    plugins/
```

Startup creates JSContext, installs its exception handler and Native bridge, evaluates the minimal loader, then requires `/bootstrap.js`. Bootstrap exposes runtime metadata, health check, module diagnostics, and deliberately loads `/compat/browser-compat.js`. Other modules remain lazy.

## CommonJS contract

Supported: `require`, `module`, `module.exports`, `exports`, `__filename`, `__dirname`, relative/absolute logical paths, optional `.js`, cache identity, and partial exports for circular dependencies.

```javascript
(function (exports, require, module, __filename, __dirname,
           global, console, PokeToolRuntime, Native) {
  // module source
});
```

Reassigning `module.exports` replaces exports. Module locals remain private unless code intentionally writes to `global`. `module.parent` is the first parent; `children` tracks unique direct dependencies. The graph separately supports multiple and reverse parents.

Not supported: `import`, `export`, dynamic import, packages, Node built-ins/addons, index/package.json resolution, npm, or remote modules.

## Resolution and canonical IDs

- `./a` from `/modules/main.js` resolves to `/modules/a.js`.
- `../shared/a` is normalized but cannot escape logical root.
- `/compat/browser-compat` resolves to `/compat/browser-compat.js`.
- `./a` and `./a.js` share one canonical cache key.
- Empty IDs, null bytes, URL/schemes, backslashes, Windows paths, non-JS extensions, and root traversal are rejected.
- A leading `/` denotes the logical JavaScript root, never the device filesystem.

## Lifecycle, cache, and circular dependencies

```text
Requested -> Resolved -> SourceLoaded -> CachedAsLoading
          -> Compiled -> Executing -> Loaded
                                 \-> Failed -> CacheEntryRemoved
```

A module is cached before execution. A circular require receives its current partial `module.exports`, without re-execution, native locks, or deadlock. A thrown module is removed from cache and may be required again. Cache and mutable exports are never shared across runtimes.

The per-runtime graph records nodes, direct/reverse edges, load order, loaded/loading/failed state, circular markers, source bytes, and execution duration. It is cleared at stop.

## Globals, console, timers

- `global.global === global`
- `global.PokeToolRuntime === PokeToolRuntime`
- `global.Native === Native`
- `performance.now()` uses a monotonic clock.

Console supports `debug`, `log`, `info`, `warn`, and `error`. Multiple values are formatted with depth/item limits, circular values are safe, oversized output gets an explicit truncation marker, and Native.Logger redaction remains in force.

`setTimeout`, `clearTimeout`, `setInterval`, and `clearInterval` use cancellable native tasks on `MainActor`. IDs are runtime-local, clear is idempotent, interval callbacks do not overlap on the single JSContext execution context, and callbacks are released after clear/stop. This is not a Node event loop. `queueMicrotask` is intentionally not emulated; native JavaScriptCore Promise scheduling remains authoritative.

## Threading and runtime lifecycle

Runtime, module execution, bridge calls, diagnostics, and timer callbacks are all `MainActor`; JSContext is never accessed concurrently. CommonJS `require` reads bounded local bundle data synchronously, but never performs network work or blocks on async synchronization. No semaphore or `DispatchGroup.wait` is used.

Stop is idempotent and:

- prevents new native operations and timers;
- cancels timers and releases callback JSValues;
- clears module cache and graph;
- releases exception handler and JSContext;
- retains the existing BrowserSession ownership policy.

## Errors and security

Structured `RuntimeModuleError` supports:

`MODULE_NOT_FOUND`, `INVALID_MODULE_ID`, `MODULE_PATH_OUTSIDE_ROOT`,
`MODULE_SOURCE_UNAVAILABLE`, `MODULE_COMPILE_FAILED`,
`MODULE_EXECUTION_FAILED`, `MODULE_EXPORT_FAILED`,
`CIRCULAR_DEPENDENCY_ERROR`, `MODULE_CACHE_ERROR`,
`MODULE_RUNTIME_STOPPED`, `RESOURCE_LIMIT_EXCEEDED`,
`UNSUPPORTED_MODULE_FEATURE`, and `INTERNAL_MODULE_ERROR`.

Errors carry safe logical IDs and phase (`resolve/load/compile/execute/cache/timer`). They do not expose absolute paths, full source, credentials, cookies, passwords, OTP, or payment data. Source is only loaded from application-controlled providers.

## Resource limits

- 512 modules per runtime
- 1 MiB source per module
- 16 MiB total loaded source
- dependency depth 128
- logical path length 512
- 128 active timers
- timer delay 4–120,000 ms
- console payload 16 KiB, depth 4, 50 items per collection

Module source is never silently truncated.

## Debug inspector and hot reload

The Debug Dashboard Module Inspector runs a fixture self-test and displays runtime ID/state, module version, cache/loading/failure state, dependency graph, circular markers, duration, timer count, source bytes, limits, and last errors.

Debug builds may clear/reload a non-executing module and optionally direct reverse dependents. Release mutation rejects as unsupported. There is no file watcher or server source. Phase 5 cannot automatically dispose arbitrary resources created by future modules, so business hot reload requires a later lifecycle contract.

## Example

```javascript
// a.js
exports.value = "A";

// b.js
module.exports = { value: "B" };

// main.js
const A = require("./a");
const B = require("./b");
module.exports = { a: A, b: B };
```

## Phase 5 / Phase 6 boundary

Phase 5 ends at the module/runtime foundation. A later phase may select and migrate business entry modules incrementally. There is no `core.js`, `runner.js`, original `web.js`, OTP, mode, account flow, website service, remote loader, or plugin implementation here.
