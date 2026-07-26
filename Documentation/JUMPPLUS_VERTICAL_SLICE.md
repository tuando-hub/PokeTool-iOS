# Jump+ vertical slice

Phase 9 adds `/modules/jumpplus/jumpplus-entry` with `jumpplus.register`,
`jumpplus.login`, `jumpplus.premium`, and `jumpplus.subscribe`. It was rewritten
from audited `modes/buyjumpplus.js` and `services/jumpplus.js`, retaining actual
URLs, fields, product ID, and GETOtp mode while replacing fixed waits with
URL + title + DOM verification.

Each task owns one isolated browser and destroys it in `finally`. Registration
submits once, distinguishes mail-sent/duplicate/validation states, and accepts
only an exact HTTPS confirmation host/path. Premium product
`10834108156675977993` is verified before payment.

Payment data is transient. `allowFinalSubmit` defaults to false and returns
`READY_FOR_FINAL_SUBMIT` at review. Explicit final submit runs once and is never
retried. 3DS is detected, not bypassed. Current Phase 9 returns
`WAITING_FOR_3DS_USER_ACTION` and cleans the task browser; interactive durable
resume remains device-validation work.

GETOtp remains a separately deployed HTTPS service using `JumpPlusCreate`.
Unconfigured production fails deterministically; CI uses mock confirmation and
parser tests only. Jump Characters Store and its token/device APIs are excluded.

