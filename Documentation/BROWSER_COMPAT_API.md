# Browser Compatibility API

Version `1.0.0` is exposed as `PokeToolRuntime.web`. It is a JavaScript-only
compatibility layer inspired by common helpers from the legacy project. It does
not contain legacy business logic and every browser operation delegates to
`PokeToolRuntime.browser` or `Native.Browser`.

## API

| Method | Behavior |
|---|---|
| `delay(ms)` | Cancellable asynchronous delay, 0–120000 ms |
| `waitPageReady(browser, timeout)` | Polls until readyState is interactive/complete |
| `waitVisible(browser, selector, timeout)` | Requires layout dimensions and visible display/visibility/opacity |
| `waitExists` / `waitGone` | Waits for selector presence/removal |
| `waitText(browser, text, timeout)` | Waits for document text to contain text |
| `waitURL` / `waitTitle` | Supports contains string, RegExp, or local JS predicate |
| `tapButton` | Verifies existence, then delegates to native click |
| `setValue` / `clearValue` | Delegates to native reactive-compatible input operations |
| `selectValue` / `setChecked` | Delegates to native element operations |
| `evalJS` | Delegates to page evaluation without logging source |
| `getURL` / `getTitle` | Reads current page information |
| `reloadOnce` | Performs at most one explicit reload and returns structured recovery state |
| `safeDestroy` | Idempotent handle cleanup |

Predicate matchers execute entirely inside the runtime JavaScript context; they
are never passed across the native bridge or retained as native callbacks.

## Polling and cancellation

Polling defaults to 250 ms, awaits each bridge call and delay before beginning
the next iteration, and therefore does not accumulate pending Promises. Timeout
defaults to 30 seconds and is restricted to 100–120000 ms. Runtime stop cancels
the currently pending native Promise through the Phase 3 registry; the context
and subsequent polling are released. Browser destruction maps subsequent
polling errors to `BROWSER_DESTROYED`.

There is no hidden retry in the base BrowserHandle. `reloadOnce` is the only
recovery helper and reloads no more than once.

## Errors

Compatibility failures are structured Error objects. Codes include:

- `WAIT_TIMEOUT`
- `ELEMENT_NOT_FOUND`
- `ELEMENT_NOT_VISIBLE`
- `INVALID_SELECTOR`
- `BROWSER_DESTROYED`
- `OPERATION_CANCELLED`
- `RELOAD_RECOVERY_FAILED`
- `INVALID_ARGUMENT`
- `INVALID_MATCHER`

Errors contain operation and safe details but never full JavaScript source,
HTML, authorization/cookie values, passwords, tokens, OTP or card data.

## Example

```javascript
const browser = await PokeToolRuntime.browser.create();

await PokeToolRuntime.web.waitPageReady(browser, 30000);
await PokeToolRuntime.web.waitVisible(browser, "#email", 15000);
await PokeToolRuntime.web.setValue(browser, "#email", "test@example.com");
await PokeToolRuntime.web.tapButton(browser, "#submit");
await PokeToolRuntime.web.safeDestroy(browser);
```

## Boundary

This is not a complete `web.js` port. It contains no account flow, OTP, modes,
website selectors, automatic login, proxying, stealth, CAPTCHA behavior or
event subscription. Longer-lived callback/event delivery remains outside this
phase.
