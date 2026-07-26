# Robust Web Flow Engine

## Architecture

```text
WebFlowEngine
  -> FlowContext / cancellation token
  -> FlowStep
      -> PageGuard precondition
      -> Action through BrowserHandle/PokeToolRuntime.web
      -> TransitionGuard
          -> destination/intermediate PageDescriptors
          -> bounded retry/recovery
  -> structured history/checkpoint/result
```

The engine is CommonJS JavaScript and never accesses WKWebView. Native browser
primitives remain retry-free; business-level retry is owned only by
TransitionGuard.

## PageDescriptor

A descriptor may combine URL, title, ready state, selectors, body text and a
JavaScript-only custom predicate:

```javascript
{
  name: "Fixture Login",
  url: {type: "contains", value: "/login"},
  title: {type: "includes", value: "Login"},
  selectors: [
    {name: "form", selector: "#login", state: "visible", required: true}
  ],
  readyState: ["interactive", "complete"],
  confidencePolicy: {type: "minimumMatches", minimum: 3}
}
```

URL supports exact, contains, startsWith, regex and predicate. Title supports
exact, includes, includesAny, regex and predicate. Selectors support exists,
visible and gone; multiple entries express any/all through required/optional
signals and confidence policy. Text supports includes, includesAny and excludes.
Functions never cross the native bridge.

Important product descriptors should use at least two independent signals.

## PageGuard

`inspect`, `matches`, `waitFor`, `assert`, `describeCurrent`, and
`captureMismatch` return structured URL/title/ready-state, matched/missing
signals, elapsed time and a bounded redacted text excerpt. A sensitive
descriptor suppresses text diagnostics. Screenshot capture is Debug/explicit
only and can be disabled per sensitive step.

Polling is sequential, 100–2,000 ms, and shares one finite total timeout.
Browser destruction, runtime stop and cancellation are not swallowed.

## TransitionGuard

A verified transition follows:

```text
verify before -> action -> observe state/navigation -> verify destination
```

Intermediate descriptors are permitted but do not reset the total deadline.
URL/title history is bounded to 32 entries. An action returning successfully is
not by itself a successful step; the destination descriptor must match.

Retry is explicit and bounded to five attempts. Default retry codes are page or
transition timeouts and visibility waits. Configuration/selector errors,
cancellation and runtime stop are not retried.

Recovery supports none, wait-again, reload-once, go-back-once,
navigate-to-known-URL and JavaScript-local custom recovery. Dangerous recovery
is never selected implicitly. `reloadOnce` remains limited to one attempt per
transition recovery scope.

## Unexpected pages

The generic registry recognizes login required, session expired, access denied,
maintenance, rate limiting, CAPTCHA, terms, error and network-error states.
These are generic text descriptors only; real vertical slices must add
multi-signal descriptors. CAPTCHA is detected and reported, never bypassed.

## Diagnostics and checkpoints

Failures retain safe signal results, transition history, step/attempt/duration
and cause code. Password, OTP, token, cookies, authorization, payment details,
full HTML and raw scripts are excluded. Checkpoints contain flow/task/step IDs,
state, timestamp and caller-approved safe payload only. Resume execution remains
a foundation for a later vertical slice.

## Cancellation and limitations

Cancellation is checked before each action, poll and task boundary. Runtime stop
also cancels native Promise registries. JavaScript Promise execution cannot
preempt arbitrary synchronous executor code; executors must cooperate through
the provided token. Full persisted resume and browser recreation with sensitive
form policy are not implemented in Phase 7.
