# Flow validation matrix

Evidence is source-level and CI/mock-based unless marked live. Website/provider flows require external credentials and are never claimed live here.

| Group | Mode | UI | Router | Executor | Service | Mock Test | Simulator Test | Live Test | STOP | Cleanup | Status | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Pokémon Center | pokemon.create | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `PokemonVerticalSliceTests`, pokemon-executor |
| Pokémon Center | pokemon.lottery | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `PokemonVerticalSliceTests` |
| Pokémon Center | pokemon.checkResult | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `pokemon-check-result-mode.js` |
| Pokémon Center | pokemon.changeProfileOrder | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `pokemon-change-profile-order-mode.js` |
| Pokémon Center | pokemon.changeEmail | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `pokemon-change-email-mode.js` |
| Pokémon Center | pokemon.buy | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `pokemon-buy-mode.js` |
| Jump+ | jumpplus.register | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `JumpPlusVerticalSliceTests` |
| Jump+ | jumpplus.login | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpplus-login.js` |
| Jump+ | jumpplus.premium | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpplus-payment.js` |
| Jump+ | jumpplus.subscribe | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpplus-payment.js` |
| JumpCS | jumpcs.prepareSession | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `JumpCSVerticalSliceTests` |
| JumpCS | jumpcs.register | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpcs-executor.js` |
| JumpCS | jumpcs.verifyPhone | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `JumpCSVerticalSliceTests` |
| JumpCS | jumpcs.validatePhoneOtp | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpcs-task-schema.js`, `jumpcs-executor.js` |
| JumpCS | jumpcs.profile | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpcs-profile.js` |
| JumpCS | jumpcs.checkout | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpcs-checkout.js` |
| JumpCS | jumpcs.buy | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `jumpcs-checkout.js` |
| Tools | Phone OTP settings | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | N/A | PASS | PASS | MOCK PASS | `PhoneGatewayViewController.swift` |
| Tools | Native.PhoneOtp | PASS | PASS | PASS | PASS | PASS | LIVE REQUIRED | LIVE REQUIRED | PASS | PASS | MOCK PASS | `PhoneOtpBridgeService.swift` |

## External blockers

Live website, mailbox, SMS-provider, payment, 3DS, and physical-device validation require user-controlled credentials/devices. CI uses sanitized fixtures and mocks only.
