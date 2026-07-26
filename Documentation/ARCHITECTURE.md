# PokeTool iOS Architecture

## Principles

- UIKit owns presentation.
- View models own presentation state, not UIKit objects.
- `BrowserManager` is the only browser entry point.
- `BrowserPool` owns multiple `BrowserSession` objects.
- `BrowserSession` alone owns its `WKWebView` and WebKit stores.
- JavaScriptCore receives opaque browser identifiers only in future phases.
- Native Bridge namespaces expose capabilities, never UIKit or WebKit objects.
- JavaScript-facing events use the `Events` namespace and the same EventBus envelope as native publishers.
- App services communicate through direct protocols for request/response and EventBus for cross-cutting events.
- No global service singleton is required.
- Core never depends on a concrete plugin.

## Dependency graph

```text
SceneDelegate
  └─ DependencyContainer [scene lifetime]
      ├─ AppStateStore [scene]
      ├─ NativeEventBus [scene]
      ├─ UnifiedLogger [scene]
      ├─ BrowserManager [scene]
      │   └─ BrowserPool [scene]
      │       └─ BrowserSession [explicit]
      │           ├─ WKWebView
      │           ├─ WKWebsiteDataStore
      │           └─ WKHTTPCookieStore
      ├─ FileStore [scene]
      ├─ NetworkClient [scene]
      ├─ KeychainStore [scene]
      ├─ NotificationService [scene]
      └─ JavaScriptRuntimeFactory [scene]
          └─ JavaScriptRuntime [run]
              ├─ JSContext
              └─ NativeBridge [run]
                  └─ Namespaced bridge objects
```

## Layer direction

```text
Presentation → Application → Domain
                         ↘ Infrastructure
BusinessRuntime → Domain + Bridge interfaces
Plugins → Core service interfaces

Core ─X→ concrete Plugins
BusinessRuntime ─X→ UIKit
BusinessRuntime ─X→ WebKit
NativeBridge ─X→ UIKit/WKWebView values
```

## Browser lifecycle

```text
BrowserManager.createBrowser(metadata, userAgent)
  → BrowserPool allocates ownership slot
  → BrowserSession creates WKWebView configuration and stores
  → BrowserPool retains BrowserSession
  → EventBus publishes browser.created

BrowserManager.destroyBrowser(browserId)
  → BrowserPool releases mapping
  → BrowserSession stops loading and detaches delegates
  → EventBus publishes browser.destroyed
  → ARC releases WebKit objects when no presentation reference remains
```

Phase 0.5 intentionally defines no loading, evaluation, clicking, selector, or automation operation.

## Runtime lifecycle

```text
JavaScriptRuntimeFactory.makeRuntime()
  → NativeBridgeFactory creates run-scoped namespaces
  → JavaScriptRuntime creates one JSContext
  → bootstrap health check
  → runtime consumer completes
  → stop() clears exception handler and releases JSContext
```

The runtime layer imports Foundation and JavaScriptCore only. It never imports UIKit or WebKit. Future browser calls cross the Native Bridge using serialized `browserId` values.

## EventBus

EventBus carries immutable `PlatformEvent` envelopes for lifecycle, diagnostics, state broadcasts, and JavaScript/native events. Direct protocol calls remain appropriate for commands that require an immediate response. EventBus must not become a hidden command dispatcher.

## Logging

All components depend on the `Logging` protocol. `UnifiedLogger` routes category-based messages to Apple Unified Logging. Categories are browser, runtime, bridge, network, storage, UI, plugin, and system. Sensitive metadata must be redacted before logging.

## Plugin boundary

Phase 0.5 defines plugin-facing contracts but no implementation. Future plugins receive `PluginContext`, restricted service resolution, EventBus, logger, and bridge access. Core does not import, discover, or instantiate concrete plugins.

## Lifecycles

| Service | Lifecycle |
|---|---|
| DependencyContainer | Scene |
| AppStateStore | Scene |
| EventBus | Scene |
| UnifiedLogger | Scene |
| BrowserManager/Pool | Scene |
| BrowserSession | Explicit create/destroy |
| File/Network/Keychain services | Scene |
| JavaScriptRuntimeFactory | Scene |
| JavaScriptRuntime/JSContext | One run |
| NativeBridge namespaces | One run |
| ViewModel | Screen |
| Plugin | Not implemented |
