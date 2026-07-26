# Jump Characters Store vertical slice

Phase 10 adds `/modules/jumpcs/jumpcs-entry` and six intents. `jumpcs.buy` is
the sequential end-to-end product path: Jump+ GraphQL authentication, exact
store URL/token validation, isolated browser, product/cart/checkout and a
review stop. Phone/SMS is provider-backed and reports `requiresConfiguration`
unless a deterministic mock is supplied.

The audited source used the GraphQL `Login`, `CreateCharacterStoreUrl`, and
`Logout` operations, `X-GIGA-DEVICE-ID`, and a bearer cache. Tokens are now
isolated per account in Keychain-backed secrets. The legacy OTP North endpoint
and credentials are not copied into the app. A future configured adapter owns
that integration; CI uses only the mock provider.

Final order submission is explicit-only and one-shot. An unknown result is
terminal and is never submitted again. Payment, OTP, bearer, device and address
data are transient and redacted from results/events.

