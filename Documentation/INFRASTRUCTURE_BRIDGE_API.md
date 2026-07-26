# Infrastructure Bridge API

## Architecture and lifecycle

```text
JavaScript module
  -> PokeToolRuntime compatibility API
  -> Native namespace Promise API
  -> InfrastructureBridgeNamespace
  -> typed bridge service
  -> injected native implementation
```

All namespaces use API version `1.0.0`, a shared bounded Promise registry and this error schema:

```javascript
{
  name, code, message, namespace, operation,
  operationId, runtimeId, retryable, details
}
```

Runtime stop rejects/cancels pending operations, releases resolver JSValues and prevents new work. It does not erase persistent files, Keychain items or scheduled notifications. JSContext access and Promise settlement occur on `MainActor`; URLSession and actor-isolated file work do not synchronously wait on the main thread.

## Storage

`Native.Storage` and `/compat/storage-compat` expose key/value operations plus text, JSON, base64 binary, info/list, directory, move/copy/remove and temporary-file operations. Logical roots are `/data`, `/cache`, `/logs`, `/results`, `/temp`, and `/downloads`.

Paths containing root escape, null bytes, backslashes, URL schemes or unsupported roots are rejected. Writes are atomic and do not overwrite unless `{overwrite:true}`.

Key/value supports finite JSON values. Limits: key 256 characters, value 256 KiB, file 8 MiB, path 512 characters and list 1,000 entries.

Main errors: `STORAGE_INVALID_KEY`, `STORAGE_INVALID_PATH`,
`STORAGE_PATH_OUTSIDE_ROOT`, `STORAGE_NOT_FOUND`,
`STORAGE_ALREADY_EXISTS`, `STORAGE_SERIALIZATION_FAILED`,
`STORAGE_FILE_TOO_LARGE`, `STORAGE_IO_FAILED`,
`STORAGE_RUNTIME_STOPPED`, and `STORAGE_CANCELLED`.

```javascript
await PokeToolRuntime.storage.set("settings", {enabled:true});
await PokeToolRuntime.storage.writeJSON("/data/settings.json", {enabled:true});
```

## Keychain

`Native.Keychain` and `PokeToolRuntime.secrets` expose `get`, `set`, `remove`, and `contains/has`. Values are UTF-8 strings up to 64 KiB. The app controls service, accessibility and access group; JavaScript cannot supply a raw access group or SecItem attributes. Values are never logged.

Current capabilities: string values are available; base64 and custom service/account/accessibility options are not yet exposed. Errors include `KEYCHAIN_INVALID_KEY`, `KEYCHAIN_ENCODING_FAILED`, `KEYCHAIN_ACCESS_FAILED`, `KEYCHAIN_RUNTIME_STOPPED`, and `KEYCHAIN_CANCELLED`.

## Network

`Native.Network.request` uses the injected ephemeral URLSession client. Compatibility helpers provide `request`, `get`, `post`, `getJSON`, and `postJSON`.

Allowed methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS. Allowed schemes: HTTP and HTTPS subject to ATS. Response types: text, JSON, base64 and metadata-only. HTTP 4xx/5xx resolve by default; `{rejectOnHTTPError:true}` rejects with `NETWORK_HTTP_ERROR`. Browser cookies and URLSession cookies are never synchronized implicitly.

Limits: URL 4,096 characters, 64 headers/32 KiB, request 4 MiB, response 16 MiB, timeout 100–120,000 ms and 64 pending namespace operations. TLS validation remains system-default. Explicit redirect policy/count control is a documented foundation limitation; system URLSession behavior is used.

## System and Device

`PokeToolRuntime.system` exposes app/runtime info, wall and monotonic time, cancellable sleep, UUID, base64 secure random bytes, memory info and safe environment metadata. Random bytes are limited to 64 KiB and sleep to 120 seconds. Shell commands, process environment and filesystem locations are unavailable.

`PokeToolRuntime.device` exposes public, non-sensitive platform/system/model-category, screen, locale, language, timezone, low-power and thermal information. It does not expose UDID, IMEI, serial, MAC, advertising ID, Wi-Fi, location, contacts, photos or clipboard. Installation ID is reported unsupported in this version rather than fabricated.

## Notification

`Native.Notification` supports explicit authorization status/request, immediate or one-shot time-interval schedule, cancellation, pending/delivered identifiers and delivered cleanup. Calendar triggers are not yet supported. Permission is never requested at startup. Notifications do not imply background automation.

## Events

JavaScript may emit only `js.*`, `runtime.*`, or `plugin.*`; native-reserved names are rejected. Native EventBus receives serialized bounded payload diagnostics. `PokeToolRuntime.events` provides runtime-local `on`, `off`, `once`, `next`, and `emit`, with 128 subscriptions and timeout cleanup. Delivery is ordered synchronously after the native emit Promise resolves. Handler exceptions are logged without crashing.

Long-lived native EventBus-to-JS callbacks are intentionally not exposed in version 1.0, avoiding JSValue/EventBus retain cycles. Capability reports `nativeSubscriptions:false`.

## Logger and redaction

`Native.Logger.debug/info/warning/error` uses injected unified logging. Console adds runtime/module metadata and safe circular formatting. Shared case-insensitive redaction covers authorization, proxy authorization, cookies, password/pass variants, tokens, bearer, secret, OTP/verification codes and card/CVV/CVC/PIN fields. Redaction affects diagnostics, not operation results.

## Capabilities and versioning

Each namespace exposes `.version` and `.capabilities()`.
`PokeToolRuntime.infrastructure.capabilities()` aggregates them. Patch releases are compatible fixes, minor releases add compatible API and major releases may break the contract.

## Known limitations

- No arbitrary filesystem, remote code, shell, TLS bypass, proxy or cookie synchronization.
- Network redirect count/control and injectable JavaScript debug transport are not complete.
- Keychain custom service/accessibility and installation ID are not exposed.
- Calendar notifications are not exposed.
- Native-to-JavaScript long-lived EventBus delivery is not exposed.
- No JSBox globals are installed.
