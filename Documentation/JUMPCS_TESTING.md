# JumpCS testing

JavaScriptCore tests cover entry/capabilities, exact store URL validation,
same-phone invariant, provider configuration/mock behavior, result redaction,
and default final-submit safety. Sanitized fixtures cover API responses and
entry, profile, phone, SMS, product, cart, card, review, completion, CAPTCHA
and maintenance states. CI never calls GraphQL, JumpCS, OTP North, a mailbox,
or a payment provider.

Real provider, current website DOM, SMS and final-order behavior remain
controlled on-device tests with user-supplied configuration.

