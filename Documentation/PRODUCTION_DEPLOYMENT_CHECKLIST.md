# Production deployment checklist

Set gateway API key and provider configuration only in secure server deployment. Use HTTPS, verify health from a physical device, run mock lifecycle tests, then perform a controlled live phone/SMS test. Keep email OTP credentials in the existing GETOtp deployment. Do not enable final payment/order submission without explicit operator approval. CI must use mock providers and sanitized fixtures.
