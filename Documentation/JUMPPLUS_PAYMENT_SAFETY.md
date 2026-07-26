# Jump+ payment safety

Payment input exists only on the validated task object and is erased in the
executor `finally`. Verification uses digit counts but persists no digits.
Logs/diagnostics redact card, security, and expiration keys. Screenshots
are disabled by policy for password, credit, review, and 3DS steps.

Review is the default stopping point. `allowFinalSubmit` must literally be
`true`; Debug builds and mode names do not enable it. Immediately before final
submit, the review descriptor and product are verified and an irreversible
event is emitted. The action is clicked once. Unknown outcomes return
`JUMPPLUS_SUBSCRIPTION_STATE_UNKNOWN` without resubmission.

3DS is detected and never bypassed. Manual issuer interaction and durable
resume require a future explicit application-level browser ownership design.
