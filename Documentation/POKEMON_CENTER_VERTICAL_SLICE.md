# Pokemon Center vertical slice

Phase 8 adds create account, lottery entry, check result, change order delivery
profile, change email and buy. `/modules/pokemon/pokemon-entry` validates tasks
and dispatches through a mode registry.

Each task owns an isolated browser and destroys it in `finally`. Important pages
combine URL, title and characteristic DOM signals. CAPTCHA, maintenance and
expired sessions are typed terminal states.

Buy stops at the verified review page unless `allowFinalSubmit` is explicitly
true. An uncertain final-submit outcome becomes
`POKEMON_PURCHASE_STATE_UNKNOWN` and is never submitted again.

OTP is hybrid: Node owns IMAP/MIME while the app owns flow and mode mapping.
Production reports `requiresConfiguration` until the HTTPS service URL and API
key are supplied. CI uses deterministic mocks.
