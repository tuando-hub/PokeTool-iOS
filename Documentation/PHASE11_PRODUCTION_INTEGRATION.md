# Phase 11 production integration

Email OTP remains the existing GETOtp service and is separate from phone/SMS OTP. Phone verification uses the provider-neutral HTTPS gateway in `Services/PhoneOtpGateway`; the iOS client never receives provider names, provider credentials, order keys, or provider status strings. The gateway ships deterministic `mock` and explicit `unconfigured` providers; production adapters are selected only on the server. Final purchase/order submission remains disabled by default and CI uses mocks only.
