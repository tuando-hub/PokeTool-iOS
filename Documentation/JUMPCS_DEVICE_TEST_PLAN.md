# JumpCS device test plan

1. Verify public GraphQL configuration with a test account and inspect only
   redacted auth/store diagnostics.
2. Open a store URL without registration or purchase.
3. Verify product descriptor and cart navigation without adding an item.
4. With an approved phone provider, test same-phone profile/SMS and release
   cleanup.
5. Drive checkout to review with `allowFinalSubmit` false.
6. Only a controlled account/product/payment may test explicit final order.

No credentials, tokens, card data, mailbox data or provider secrets belong in
the repository or CI.
