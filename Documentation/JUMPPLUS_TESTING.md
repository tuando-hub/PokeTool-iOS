# Jump+ testing

Swift/JavaScriptCore tests cover entry capabilities, task validation,
multi-signal pages, strict confirmation URLs, redaction, payment normalization,
review default safety, sanitized fixtures, and event delivery. GETOtp Node tests
cover exact-host extraction under `JumpPlusCreate`.

Fixtures model signup, confirmation, login, premium, credit, review, 3DS,
completion, payment failure, maintenance, CAPTCHA, rate limit, and session
expiry. CI never contacts Jump+, a mailbox, or a payment processor.

The Debug Dashboard provides a descriptor self-test and an in-memory JSON task
runner. Real signup email timing, current production DOM, actual card
validation, issuer 3DS, and final subscription require controlled on-device
acceptance testing with user-supplied secrets.

