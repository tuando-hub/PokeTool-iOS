# Browser Bridge API

ABI version: `1.0.0`

Every listed low-level operation returns a real Promise. Rejections are
structured JavaScript Error objects with `code`, `operationId`, `browserId`,
`operation`, `retryable`, and safe `details`. A returned Promise also has an
`operationId` property and may be cancelled with
`Native.Browser.cancelOperation(operationId)`.

## Lifecycle and navigation

| API | Arguments | Result |
|---|---|---|
| `create(options?)` | persistence (`isolatedNonPersistent` default or `sharedPersistent`), userAgent, string metadata | browserId string |
| `destroy(browserId)` | browserId | null; repeated destroy rejects `INVALID_SESSION` |
| `load(browserId, request)` | URL, method, headers, UTF-8 body, cachePolicy, timeoutMs | null |
| `reload(browserId)` / `reloadFromOrigin(browserId)` | browserId | null |
| `stop/back/forward(browserId)` | browserId | null |

```javascript
const browserId = await Native.Browser.create();
await Native.Browser.load(browserId, {
  url: "https://example.com", method: "GET", timeoutMs: 30000
});
```

## Page, DOM, and elements

`evaluate`, `snapshot`, `url`, `title`, `readyState`, `html`, `text`, `exists`,
`count`, and `query` map only JSON-safe values. Element methods currently
exposed are `click`, `focus`, `blur`, `setValue`, `type`, `clear`,
`setChecked`, `selectValue`, `selectIndex`, `submit`, and `scrollIntoView`.
Arguments are passed to Phase 2 services; the bridge contains no DOM scripts or
website-specific selectors.

`waitNavigation(browserId, condition, options?)` accepts started, committed,
finished, failed, URL equals/contains/prefix/suffix/regex, and title
equals/contains/regex. Timeout defaults to 30 seconds and is bounded. It is
reported as foundation because Phase 2 currently uses bounded lightweight
snapshot polling.

`waitElement`, `waitReady`, `scroll`, and network-idle are not exposed because
their native lifecycle is not yet complete.

## Cookies and website data

`cookies(browserId, filter?)`, `importCookies(browserId, cookies)`, and
`clearCookies(browserId)` operate only on the selected session. Filters support
domain, name, and URL. Cookie values are returned to the explicit caller but
never logged.

`websiteData(browserId)` and `clearWebsiteData(browserId, scope?)` expose native
WebKit record-level operations. Per-key localStorage/sessionStorage APIs are not
exposed. Direct set/delete cookie APIs remain unavailable until native Phase 2
mutation operations are complete.

## User agent, viewport, and screenshot

`setUserAgent`, `resetUserAgent`, and `viewport` use serializable values.
User-agent changes apply to subsequent navigation.

`screenshot(browserId, options?)` accepts PNG/JPEG, viewport/fullContent and
JPEG quality. It returns an opaque controlled `fileId`, format, dimensions,
timestamp and browserId; it never accepts an output path or returns image bytes.
Full-content capture is capability `limited`.

## Capabilities and wrapper

`Native.Browser.version`, `getVersion()`, and `capabilities()` support ABI
negotiation. Unsupported foundations are reported accurately.

The developer-facing wrapper stores only browserId:

```javascript
const browser = await PokeToolRuntime.browser.create();
await browser.load("https://example.com");
const title = await browser.title();
await browser.destroy();
```

Calling a wrapper method after destroy rejects locally with `INVALID_STATE`.
There is no automatic retry and no JSBox or business compatibility layer.
