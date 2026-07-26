# Migration Strategy

Migration no longer requires preserving JSBox source line-for-line. Functions
may be split, signatures changed, callbacks converted to Promise, global state
replaced, and unsuitable code rewritten or moved to native Swift when that
improves correctness, security and maintainability.

The project will not build a complete JSBox emulator. Compatibility adapters are
added only when an actual vertical slice needs them.

Each mode is migrated as one tested vertical slice:

1. Define its typed task and safe account data.
2. Define multi-signal PageDescriptors.
3. Implement actions through BrowserHandle/PokeToolRuntime.web.
4. Verify every important page/state transition.
5. Add explicit bounded retry and conservative recovery.
6. Test success, unexpected pages, cancellation and cleanup.
7. Ship that slice before starting the next mode.

Fixed delays must not replace state verification. A successful click/evaluate
does not imply a successful transition. Retry must have one owner and finite
attempts; recovery must be explicit. CAPTCHA and security pages are detected and
reported, never bypassed.

Business intent should remain recognizable, but obsolete JSBox mechanics,
unsafe polling, callback nesting, unbounded retry and scattered mutable globals
should be removed rather than copied.
