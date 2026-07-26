# JumpCS API authentication

Sanitized source operations:

- Endpoint: `https://api.shonenjumpplus.com/api/v1/graphql`
- `Login($input: LoginInput!)`
- `CreateCharacterStoreUrl`
- `Logout`
- Headers include `X-Giga-Platform`, `X-GIGA-DEVICE-ID`, Apollo operation
  metadata, and an app user-agent.

Device UUIDs and bearer values are account-scoped Keychain secrets. The store
mutation is not retried when its outcome is unknown. GraphQL `errors` are
rejected even when HTTP status is 200. `USER_IS_ALREADY_LOGGED_IN` has no blind
logout/login loop; it returns a typed recovery error unless an explicit safe
fixture/configuration is present. Store URLs require the exact HTTPS host and a
validated `subscr_token`; diagnostics contain only a redacted URL and a boolean
token-present flag.

