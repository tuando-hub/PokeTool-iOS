# Pokemon error codes

`PokemonError` preserves a safe cause code. The taxonomy covers invalid tasks,
credential/account/CAPTCHA/session states, maintenance/rate limiting, OTP,
registration, entry/result/profile/email/cart/checkout/payment/order outcomes,
page mismatch, unexpected page, bounded retry, cancellation and runtime stop.

The canonical list is in `pokemon-errors.js`. Diagnostics exclude credentials,
OTP, confirmation tokens, cookies, authorization, card data and full HTML.
