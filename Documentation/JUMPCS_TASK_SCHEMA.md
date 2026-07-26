# JumpCS task schema

Tasks contain `id`, one of the six `jumpcs.*` modes, `account`, optional
`profile`, `product`, `payment`, `providers`, and bounded `options`. Product
URLs must be under `https://jumpcs.shueisha.co.jp/shop/g/g.../`. `buy` requires
payment input, while phone rental is opt-in and provider configuration is never
inferred.

`allowFinalSubmit` defaults to false. Passwords, bearers, device IDs, store
tokens, provider credentials, phone OTPs, cards, CVV, cookies and full address
are never persisted or emitted.

