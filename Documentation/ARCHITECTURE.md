# PokeTool iOS Architecture

## Phase 3: Browser Bridge

```text
Business JavaScript
  -> PokeToolRuntime.browser wrapper
  -> Native.Browser Promise ABI
  -> BrowserBridgeNamespace / Promise registry
  -> BrowserBridgeService
  -> BrowserManager
  -> Browser operation services
  -> BrowserSession / WKWebView
```

The low-level ABI is version `1.0.0`. JavaScript passes acyclic JSON payloads
through one native `invoke(method,payload)` boundary. `BrowserBridgeService`
performs centralized typed decoding, resource validation, BrowserManager calls,
result encoding and error mapping. Neither JavaScript nor the bridge receives
BrowserPool, BrowserSession, WKWebView, UIKit objects, NSError, UIImage, Data,
native Cookie objects, URL or Date objects.

### Promise and cancellation lifecycle

```text
Created -> Registered -> Running -> Resolved / Rejected / Cancelled -> Released
```

Each call creates a real JavaScript Promise with an `operationId`. The
MainActor-owned registry retains resolve/reject only until the first terminal
outcome. `Native.Browser.cancelOperation(id)` cancels explicitly. Runtime stop
cancels and rejects every pending Promise, clears the registry, then destroys
sessions created by that runtime. Destroying a browser deterministically rejects
an unknown ID and cancels other bridge work associated with the destroyed ID.

JavaScriptCore and all JSValue access are MainActor-confined. BrowserManager is
also MainActor-confined. Structured concurrency crosses the boundary without
semaphores, synchronous waits, or DispatchGroup waits. Promise settlement and
eventual JS callbacks therefore return to the context's actor.

### Values and errors

The JS wrapper rejects functions, symbols, bigint, cyclic values and non-finite
numbers before native decoding. Native accepts null, Boolean, finite number,
string, array and plain string-keyed object. Results use the same JSON domain;
timestamps are ISO-8601 strings. BrowserValue is recursively converted without
exposing host objects.

Rejected values are normalized to JavaScript Error objects with `name`, `code`,
`message`, `operationId`, `browserId`, `operation`, `retryable`, and safe
`details`. Full scripts, HTML, cookie values, authorization headers, form bodies
and sensitive values are excluded from errors and logs.

### Ownership, limits, and capabilities

Runtime ownership is deterministic: runtime-created sessions are destroyed on
runtime stop. Scene/presentation sessions are not owned by the runtime.

Limits include 64 pending Promises, 1,000,000-character scripts, 5,000,000-
character HTML results, 2 MB bridge payloads, 64 headers, 32 metadata entries,
and 100 ms–120 s timeouts. Logger messages and metadata are bounded and passed
through native redaction.

Capability detection is required. Navigation, evaluation, DOM queries, element
interaction, cookies, website data and screenshots are exposed. Navigation
waiting is marked `foundation`; full-content screenshots are `limited`.
Element MutationObserver waiting, network idle, download/upload, page-storage
keys, cookie mutation and reload-once recovery are not exposed as complete.

Browser event delivery remains unavailable in this phase; the namespace is kept
as a future pull-based boundary to avoid long-lived JS callbacks. EventBus is
not used as a command dispatcher.

### Compatibility and Phase 4 boundary

Bridge API versions are independent of app versions. Minor releases are
additive; breaking ABI changes require a major version. Code must inspect
capabilities instead of assuming support.

Phase 3 contains only bridge infrastructure and a thin developer wrapper. It
does not contain JSBox compatibility, modes, business logic, website-specific
selectors, retries, proxying, stealth, CAPTCHA handling, or Phase 4 runtime
features.

## Phase 2: Native Browser Operations

Phase 2 adds native-only operations; it does not add a JavaScriptCore Browser API
or change `bootstrap.js`.

```text
Application / Presentation
          |
   BrowserManager             only native entry point
          |
 Operation Services          navigation / JS / DOM / element / capture
          |
   BrowserSession            validation and lifecycle
          |
      WKWebView
```

`BrowserManager` accepts `BrowserID` and Foundation models, validates the
session, then delegates to injected MainActor services. BrowserPool stays
private. Runtime never receives BrowserSession or WKWebView.

### Operations and lifecycle

The native surface covers validated URL/request loading, reload/from-origin,
stop/back/forward; serializable page JavaScript; page state/HTML/text/snapshot;
safe CSS queries and controlled element interactions; bounded navigation
conditions; session cookies and website data; user-agent/viewport state; and
controlled PNG/JPEG screenshots.

```text
Created -> Validated -> Running -> Completed / Failed / TimedOut / Cancelled
                                             |
                                          CleanedUp
```

Each context carries operation ID, BrowserID, name, optional correlation ID,
timestamp, timeout and state. `BrowserOperationCoordinator` races the MainActor
work against a structured timeout, propagates cancellation, emits events and
records internal metrics. Destroy/process termination invalidates pending work.
No main-thread blocking or public callback API is used.

### Serialization, DOM, and interaction

`BrowserValue` recursively permits null, Boolean, integer, finite number, string,
array and string-keyed object. It rejects arbitrary NSObject, JSValue, UIKit and
WebKit values. Full script source and full HTML are not logged.

Selectors and arguments use `callAsyncJavaScript(arguments:)`, never raw string
interpolation. Invalid selector and missing element are distinct errors. Input
updates use the prototype value setter when available and controlled bubbling
focus/input/change/blur/click events. No website-specific selector or retry loop
exists.

### Waiting and readiness

Navigation waits are typed, regex-validated, bounded and cancellable. The current
short-interval fallback reads session snapshots; an EventBus waiter registry is
the remaining hardening item. The versioned MutationObserver element waiter is
not claimed complete yet.

Network-idle is deliberately foundation-only through
`BrowserNetworkIdleOperating`. A complete implementation must preserve original
fetch/XHR behavior, prevent wrapper stacking, uninstall on navigation/destroy,
and cannot observe WebSocket, EventSource, beacon, non-fetch/XHR subresources or
requests predating injection. Phase 2 never reports false network-idle success.

### Cookie and storage boundaries

Cookies remain isolated in the session data store. There is no implicit
cross-session sync and values are never logged. Explicit shared
`HTTPCookieStorage` synchronization remains CookieManager-owned.

`WKWebsiteDataStore` enumerates/removes records and WebKit data types. Individual
localStorage/sessionStorage keys can only be accessed through page JavaScript;
they are not mislabeled as native record APIs.

### Files, downloads, uploads, and process recovery

Screenshots use unique app-controlled cache destinations and never expose
UIImage or accept arbitrary paths. Full-content capture is subject to WebKit
memory/size limits.

Download state and controlled destination policies are session infrastructure.
Complete WKDownload delegate/progress integration remains foundation work.
`BrowserFileSelecting` keeps document-picker UI in Presentation/Application and
limits Browser Infrastructure to validated selected URLs.

On web-process termination, session state/event/metrics are updated and pending
operations are invalidated. There is no reload loop. Recovery defaults to
`none`; modeled `reloadOnce` is not enabled.

### Events, redaction, metrics, and DI

Events contain serializable identifiers, operation names, duration/outcome and
typed error categories—not WKWebView/UI objects, raw NSError, scripts, HTML,
cookie values, authorization headers, passwords or form bodies.
`BrowserRedactor` covers authorization, cookie/set-cookie, password,
token/bearer, OTP and card keys.

The scene-scoped DependencyContainer injects operation coordinator/services,
metrics, logger and destination policies. Sessions and WebKit child services
have explicit create/destroy lifetimes. No singleton, service locator,
third-party analytics, or third-party dependency was added.

### Phase 2 / Phase 3 boundary

Native.Browser remains empty and `bootstrap.js` exposes no Browser API.
Business Runtime imports neither UIKit nor WebKit. Promise bridge, legacy JSBox
business logic, modes, plugins, website automation, stealth, proxy and security
bypass remain outside Phase 2.

## Phase 1 scope

Phase 1 implements a native Browser Engine foundation. It does not implement browser automation, website-specific behavior, selectors, runtime evaluation, or a JavaScript-facing Browser API.

## Architectural principles

- UIKit owns presentation.
- View models own presentation state, not business rules.
- `BrowserManager` is the only native entry point to the Browser Engine.
- `BrowserPool` is private to `BrowserManager`.
- `BrowserSession` owns its WebKit objects and session-scoped managers.
- WebKit ownership and callbacks are isolated to `MainActor`.
- A Browser session is referenced by `BrowserID`.
- JavaScriptCore does not import UIKit or WebKit.
- The Browser Bridge namespace remains empty until Phase 2.
- EventBus carries lifecycle broadcasts, not request/response commands.
- All services receive dependencies through `DependencyContainer`.
- Core does not depend on concrete plugins.

## Top-level dependency graph

```text
SceneDelegate
  `-- DependencyContainer [scene lifetime]
      |-- AppStateStore
      |-- NativeEventBus
      |-- UnifiedLogger
      |-- FileStore
      |-- NetworkClient
      |-- KeychainStore
      |-- NotificationService
      |-- BrowserMetricsCollector
      |-- UserAgentManager
      |-- BrowserSessionFactory
      |   `-- session-scoped browser services
      |-- BrowserManager
      |   `-- BrowserPool [private]
      |       `-- BrowserSession [0...N]
      `-- JavaScriptRuntimeFactory
          `-- JavaScriptRuntime [run lifetime]
              |-- JSContext
              `-- NativeBridge [Browser namespace empty]
```

## Layer direction

```text
Presentation --> Application --> Domain
                           \--> Infrastructure

BusinessRuntime --> Domain + Bridge interfaces
Plugins         --> Core service interfaces

Core            -X-> concrete Plugins
BusinessRuntime -X-> UIKit
BusinessRuntime -X-> WebKit
NativeBridge    -X-> UIKit/WKWebView values
JavaScript      -X-> Browser Engine in Phase 1
```

# Browser Engine

## Browser dependency diagram

```text
BrowserManager
  |-- BrowserPool
  |   `-- [BrowserID: BrowserSession]
  |-- BrowserSessionFactory
  |   |-- UserAgentManager
  |   |-- BrowserEventEmitter
  |   |-- UnifiedLogger
  |   `-- BrowserMetricsCollector
  `-- BrowserMetricsCollector

BrowserSession
  |-- WKWebView
  |-- WKProcessPool
  |-- WKWebsiteDataStore
  |-- WKHTTPCookieStore
  |-- CookieManager
  |-- StorageManager
  |-- DownloadManager
  |-- Navigation model
  |-- History model
  |-- Viewport model
  `-- State machine
```

`BrowserPool` is never returned or injected outside Browser Engine construction. Consumers receive only `BrowserManager`.

## BrowserManager

`BrowserManager` is the native facade responsible for:

- Creating sessions from `BrowserSessionConfiguration`.
- Enforcing pool capacity before WebKit allocation.
- Looking up sessions and snapshots by `BrowserID`.
- Returning a WebView only for native presentation.
- Updating metadata, user agent, and viewport.
- Destroying one or all sessions.
- Selecting cleanup policy.
- Returning internal metrics snapshots.

It contains no URL loading, JavaScript evaluation, selector, click, typing, or automation API.

## BrowserPool

The pool is a `MainActor`-isolated map keyed by `BrowserID`. Its default capacity is eight sessions and is configurable through `BrowserEngineConfiguration`.

WebKit networking remains concurrent even though ownership mutations are serialized on `MainActor`. This prevents races in create/destroy/lookup while allowing several WebKit content processes and network loads to operate simultaneously.

The default capacity is a safety boundary, not an automation concurrency decision. Later phases may tune it using device memory and observed process termination metrics.

## BrowserSession

Each session owns:

- Stable `BrowserID`.
- `WKWebView`.
- Dedicated `WKProcessPool`.
- Website data store and HTTP cookie store.
- Browser and navigation states.
- Current/previous URL.
- Page title and estimated progress.
- Native history.
- Metadata and owner attributes.
- User agent.
- Viewport and safe-area metrics.
- Cookie, storage, and download managers.
- Session creation timestamp.

The default data-store policy is `isolated`, implemented with a new non-persistent `WKWebsiteDataStore`. This prevents accidental cookie sharing between accounts. A shared persistent store must be explicitly selected.

## Browser lifecycle

```text
createSession(configuration)
  -> BrowserPool.ensureCapacity
  -> emit Creating
  -> BrowserSessionFactory resolves data store and user agent
  -> BrowserSession creates WebKit objects and child managers
  -> BrowserSession enters Idle
  -> BrowserPool retains session
  -> metrics register creation
  -> emit BrowserCreated

destroySession(browserId, cleanupPolicy)
  -> remove session from BrowserPool
  -> enter Stopping
  -> stop current WebKit load
  -> cancel tracked downloads
  -> optionally clear cookies and website data
  -> invalidate observations and detach delegates
  -> enter Destroyed
  -> metrics remove active session
  -> emit BrowserDestroyed
  -> ARC releases objects after native presentation releases WKWebView
```

Removing the session from the pool before asynchronous cleanup prevents new consumers from acquiring a stopping session.

## Browser state machine

```text
Creating --> Idle
    |          |
    |          +--> Loading --> Interactive --> Ready
    |                  |             |            |
    |                  +--> Idle     +--> Idle    +--> Busy
    |                  |             |            |
    |                  +-------------+------------+--> Stopping
    |                                               |
    +-----------------------------------------------+
                                                    v
                                                Destroyed
```

Allowed transitions:

| From | To |
|---|---|
| Creating | Idle, Stopping |
| Idle | Loading, Busy, Stopping |
| Loading | Interactive, Ready, Idle, Stopping |
| Interactive | Ready, Loading, Idle, Stopping |
| Ready | Loading, Busy, Idle, Stopping |
| Busy | Ready, Loading, Idle, Stopping |
| Stopping | Destroyed |
| Destroyed | none |

Invalid transitions are rejected and logged as `BrowserError.invalidState`.

## Navigation model

`WKNavigationDelegate` and native KVO track:

- Current URL.
- Previous URL.
- Page title.
- Estimated loading progress.
- Provisional, committed, completed, failed, and process-terminated states.
- Native navigation type.
- Load start and duration.
- Append-only logical history with forward-history truncation support.

The delegate only observes and allows native WebKit navigation. It does not initiate navigation or perform automation.

## CookieManager

CookieManager wraps a session's `WKHTTPCookieStore` and supports:

- Export to codable `BrowserCookie` values.
- Import from `BrowserCookie`.
- Clear.
- Explicit synchronization to or from `HTTPCookieStorage.shared`.
- Cookie-change events and logging.

Synchronization is never automatic because shared cookies would break account isolation.

## StorageManager

StorageManager uses only public native `WKWebsiteDataStore` APIs:

- Inspect website data records.
- Clear local storage.
- Clear session storage.
- Clear WebKit caches.
- Clear all website data.
- Track storage state.

Local and session storage are addressed through the public `WKWebsiteDataTypeLocalStorage` and `WKWebsiteDataTypeSessionStorage` record types. No page JavaScript is evaluated.

## DownloadManager

DownloadManager currently owns the download model and lifecycle:

```text
Pending --> Running --> Finished
                   \--> Failed
Pending/Running -----> Cancelled
```

It tracks download IDs, filename, start time, progress, result, summary, and events. `WKDownloadDelegate` integration and destination policy are intentionally deferred.

## UserAgentManager

UserAgentManager resolves:

- System default user agent (`nil` custom override).
- A normalized custom user agent.

Changes remain session-scoped and are applied through `BrowserManager`.

## Browser events

Browser events are converted into immutable `PlatformEvent` values:

- `browser.created`
- `browser.destroyed`
- `browser.state.changed`
- `browser.navigation.started`
- `browser.navigation.committed`
- `browser.navigation.finished`
- `browser.navigation.failed`
- `browser.loading.started`
- `browser.loading.finished`
- `browser.history.changed`
- `browser.cookies.changed`
- `browser.storage.changed`
- `browser.download.started`
- `browser.download.finished`
- `browser.download.failed`
- `browser.process.terminated`

No event exposes a `WKWebView`, cookie-store object, or website data object.

## Browser errors

The typed `BrowserError` model includes:

- Navigation failure.
- Timeout.
- Web process termination.
- Invalid session.
- Invalid URL.
- Invalid state transition.
- Pool capacity exceeded.
- Cookie failure.
- Storage failure.
- Download failure.
- Unknown failure.

Errors preserve native codes/messages without introducing website-specific semantics.

## Browser metrics

Internal metrics include:

- Active session count.
- Total sessions created.
- Session creation duration.
- Last and total load duration.
- Navigation count.
- Web content process termination count.
- Memory available to the current process.

Metrics are not exposed to JavaScript. They exist for capacity tuning and diagnostics.

# Runtime lifecycle

```text
JavaScriptRuntimeFactory.makeRuntime()
  -> NativeBridgeFactory creates run-scoped namespaces
  -> JavaScriptRuntime creates one JSContext
  -> bootstrap health check
  -> runtime consumer completes
  -> stop() clears exception handler and releases JSContext
```

The runtime imports Foundation and JavaScriptCore only. The `Browser` Bridge namespace remains empty in Phase 1.

# EventBus and logging

EventBus carries lifecycle, diagnostics, and state broadcasts. Direct protocols remain the correct mechanism for commands that require an immediate response.

All components depend on `Logging`. `UnifiedLogger` routes browser, runtime, bridge, network, storage, UI, plugin, and system categories to Apple Unified Logging. Sensitive metadata must be redacted before logging.

# Plugin boundary

Plugin interfaces remain declarations only. Phase 1 adds no plugin loader, registry, discovery mechanism, or implementation.

# Service lifecycles

| Service | Lifecycle |
|---|---|
| DependencyContainer | Scene |
| EventBus / UnifiedLogger | Scene |
| BrowserManager / BrowserPool | Scene |
| BrowserSessionFactory | Scene |
| BrowserMetricsCollector | Scene |
| UserAgentManager | Scene |
| BrowserSession | Explicit create/destroy |
| Cookie/Storage/Download managers | BrowserSession |
| WKWebView / WebKit stores | BrowserSession |
| JavaScriptRuntime / JSContext | One run |
| NativeBridge namespaces | One run |
| ViewModel | Screen |
| Plugin | Not implemented |
