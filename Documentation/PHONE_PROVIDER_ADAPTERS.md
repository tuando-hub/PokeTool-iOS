# Phone provider adapters

The server owns provider selection (`PHONE_OTP_PROVIDER`) and all provider credentials. The app only speaks the stable gateway contract. `MockPhoneOtpProvider` supports deterministic tests and `UnconfiguredPhoneOtpProvider` fails explicitly; adding a real provider is a server-only adapter change and does not require a new IPA.
