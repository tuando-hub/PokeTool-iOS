# JumpCS error codes

Errors are typed `JumpCSError` values. Categories include API/auth (`JUMPCS_GRAPHQL_ERROR`,
`JUMPCS_INVALID_CREDENTIAL`, `JUMPCS_BEARER_MISSING`), store/session
(`JUMPCS_STORE_URL_INVALID`, `JUMPCS_SUBSCR_TOKEN_INVALID`), profile/phone/SMS,
product/cart/checkout, payment/3DS, order safety, cancellation and unexpected
page states. Cause codes from Native Network, Browser, provider and Flow are
preserved. Unknown final order states are never retried.

