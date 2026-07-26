# Pokemon task schema

Tasks contain `id`, one of the six `pokemon.*` modes, an in-memory `account`,
mode-specific `input`, `options`, and metadata. Account fields are email,
password, and optional IMAP email/app password.

Create requires `profile`; lottery requires `productIds`; result may include
`resultURL`, `productIds`, and `receivedAfter`; profile order requires `profile`
and `productIds`; email change requires `newEmail`; buy requires `productURL`
and may include quantity.

`options.otpProvider` supplies a runtime-only HTTPS service URL and API key.
`allowFinalSubmit` defaults false. Credentials, OTP and payment data are never
persisted; long-lived credentials belong in Keychain.
