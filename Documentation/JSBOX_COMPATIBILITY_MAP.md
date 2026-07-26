# JSBox Compatibility Map

Phase 6 provides namespaced foundations only. It deliberately does not install JSBox globals.

| JSBox API | PokeTool API | Status | Notes |
|---|---|---|---|
| `$cache.get/set/remove` | `PokeToolRuntime.storage.get/set/remove` | available | JSON-compatible bounded values |
| `$file.read/write/delete` | `PokeToolRuntime.storage.read*/write*/removePath` | partial | Controlled logical roots only |
| `$file.list` | `PokeToolRuntime.storage.list` | available | Bounded managed-directory results |
| `$http.get/post/request` | `PokeToolRuntime.network.get/post/request` | foundation available | URLSession; no implicit retry/cookie sync |
| `$device.info` | `PokeToolRuntime.device.info` | foundation available | Safe public fields only |
| `$device.isLowPowerMode` | `PokeToolRuntime.device.isLowPowerMode` | available | Public ProcessInfo state |
| `$push.schedule` | `PokeToolRuntime.notification.schedule` | partial | Immediate/time interval only |
| `$app.openURL` | none | planned | Requires explicit application/UI policy |
| `$keychain`-style secrets | `PokeToolRuntime.secrets` | available | UTF-8 string values |
| JSBox events | `PokeToolRuntime.events` | partial | Runtime-local handlers; controlled native emit |
| `$ui` | none | unsupported in runtime | UIKit remains Presentation-only |
| `$nodejs` | none | unsupported | No Node.js runtime/npm |
| Objective-C bridge | none | unsupported | Native classes are never exposed |

`$cache`, `$file`, `$http`, `$device`, `$app`, `$push`, `$ui`, and `$nodejs` remain undefined globals.
