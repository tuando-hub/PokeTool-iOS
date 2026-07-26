# Product Runtime

## Modules

```text
/modules/product/index.js
  -> /modules/core/
      constants, errors, state, task, result,
      cancellation, diagnostics
  -> /modules/runner/index.js
  -> /runtime/web-flow-engine.js
```

Product modules are loaded explicitly. Bootstrap does not start a task or load a
website mode.

## Core

Core owns validated product state: runtime/running status, mode, task, account
identifier, step, index/total, elapsed time, progress, last error and
correlation ID. Updates are controlled and publish
`runtime.state.changed`. Diagnostic helpers mask identifiers and redact
sensitive keys.

Product errors preserve flow/task/step IDs, retryability, cause code and safe
diagnostics. Taxonomy includes precondition/page/transition/action/recovery,
retry exhaustion, cancellation, timeout, runtime stop, invalid task and fatal
dependency/internal failures.

## Runner

Runner is sequential and exposes `configure`, `start`, `stop`, `isRunning`,
`current`, `results`, and `reset`. Executors remain inside JavaScript and receive
task plus correlation/cancellation/event context.

Defaults do not retry tasks. Ordinary task failure can continue; fatal runtime
errors, configured stop-on-error and user cancellation stop the queue. Per-task
timeout and between-task delay are finite. Summary reports total, succeeded,
failed, cancelled, skipped, duration and typed results.

Events include runtime state, runner/task lifecycle and flow-step lifecycle.
No parallel account execution exists in Phase 7.

## Application boundary

`ProductRuntimeService` is the Application-layer owner. It creates/starts
JavaScriptRuntime, explicitly requires the product and executor modules,
validates JSON input, starts/stops the runner, decodes summary and performs
deterministic cleanup. Production UI does not directly operate JavaScriptRuntime.

The Debug Product Flow button uses the same service with an app-bundled neutral
fixture executor. Stop requests are idempotent and visible through the product
state snapshot.

## Capabilities and limitations

Available: sequential tasks, structured state/result/errors, cooperative
cancellation, finite timeout, verified flow transitions, bounded retry/recovery
and safe checkpoint foundation.

Not available: website modes, account schema, OTP, parallel execution, durable
resume, arbitrary executor source, or preemption of non-cooperative synchronous
JavaScript.
