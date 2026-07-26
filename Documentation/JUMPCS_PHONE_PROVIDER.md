# Phone provider

Business code depends on `PhoneVerificationProvider`: authenticate, order a
number, wait for the number, wait for an OTP, cancel and release. Phase 10 ships
an unconfigured provider and a deterministic mock. It does not copy OTP North
credentials, endpoint secrets, or Node/JSBox globals into the app. Production
phone/SMS is therefore reported as `requiresConfiguration` until an approved
adapter is injected.

