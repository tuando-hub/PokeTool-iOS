# iOS production configuration

The gateway base URL is non-secret and stored in UserDefaults. The gateway API key is stored in Keychain only and is never exported in diagnostics. Email OTP remains configured through its existing GETOtp path and is not represented by the phone gateway settings. A device smoke test should validate HTTPS URL syntax and `/health` before any phone order.
