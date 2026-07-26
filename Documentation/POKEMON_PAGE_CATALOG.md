# Pokemon page catalog

All pages require the Pokemon Center Online title plus the listed URL and DOM.

| Page | URL | DOM marker | Sensitive |
|---|---|---|---|
| Login | `/login/` | email/password/submit IDs | yes |
| OTP | login/factor/auth | `#authCode` | yes |
| Terms | terms/agreement/mypage | `#terms_button` | no |
| MyPage | `/mypage/` | MyPage-specific container | private |
| Registration | login/new-customer | registration controls | yes |
| Lottery | `/lottery/apply.html` | lottery application root | private |
| Result/history | history path | `.comOrderList` or result marker | private |
| Order address | delivery-address path | address form | yes |
| Email change | mail-change path | email fields/status | yes |
| Product/cart | product/cart path | product/cart marker | no/private |
| Checkout/review | checkout/order path | state-specific container | yes |
| Order complete | complete/thank path | completion marker | private |

Unexpected descriptors cover CAPTCHA, maintenance and expired sessions. Query
strings and tokens are removed from diagnostics.
