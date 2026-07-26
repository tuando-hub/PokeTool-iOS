# SMS flow

The profile phone and provider phone are normalized and compared before SMS is
requested. A request is one-shot; polling is bounded and cancellation-aware,
and OTP matching is tied to the provider order `pkey`. Wrong/stale rows and
invalid formats are ignored. Raw OTP and provider credentials never enter logs,
events, results, or persistence.

