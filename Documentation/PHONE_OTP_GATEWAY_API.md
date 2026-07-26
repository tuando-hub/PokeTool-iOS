# Phone OTP Gateway API

Routes: `GET /health`, `POST /v1/phone/orders`, `GET /v1/phone/orders/:id`, `GET /v1/phone/orders/:id/otp`, `POST /v1/phone/orders/:id/cancel`, and `POST /v1/phone/orders/:id/release`. Bearer authentication and client `requestId` idempotency are required. Provider order IDs and provider details never cross this boundary.
