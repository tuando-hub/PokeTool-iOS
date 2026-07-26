# Real-device smoke tests

Configure an HTTPS gateway URL and Keychain API key. Run health and mock order/status/cancel/release checks first. Live SMS, checkout, 3DS, and final order operations are destructive and require explicit controlled tasks; they are never part of CI.
