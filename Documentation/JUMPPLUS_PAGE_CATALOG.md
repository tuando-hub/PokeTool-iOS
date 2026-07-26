# Jump+ page catalog

| Page | URL signal | DOM/text signal | Sensitive |
|---|---|---|---|
| `JUMPPLUS_HOME` | exact home | header + visible login trigger | no |
| `JUMPPLUS_LOGIN_POPUP` | Jump+ host | login form + signup switch | password |
| `JUMPPLUS_SIGNUP_FORM` | Jump+ host | scoped email/password/agreement | password |
| `JUMPPLUS_SIGNUP_MAIL_SENT` | Jump+ host | mail-sent text, form gone | private |
| `JUMPPLUS_SIGNUP_CONFIRMATION` | exact token path | completion text | token |
| `JUMPPLUS_LOGGED_IN_HOME` | Jump+ host | account/premium navigation | private |
| `JUMPPLUS_PREMIUM_CONFIRM` | exact product query | continue action | no |
| `JUMPPLUS_PAYMENT_METHOD` | Jump+ host | `a.payment_choose_credit_3d` | no |
| `JUMPPLUS_CREDIT_FORM` | Jump+ host | named credit form/card fields | payment |
| `JUMPPLUS_PAYMENT_REVIEW` | Jump+ host | named review form | payment |
| `JUMPPLUS_3DS` | challenge URL pattern | challenge form/frame | 3DS |
| `JUMPPLUS_SUBSCRIPTION_COMPLETE` | Jump+ host | completion text | no |

Titles accept audited Japanese variants plus explicit fixtures. CAPTCHA,
maintenance, and rate-limit descriptors are checked before continuing.
Session/access/form/payment errors are action-local classifications. Dynamic
tokens and query strings are removed from diagnostics.

