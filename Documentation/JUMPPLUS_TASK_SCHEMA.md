# Jump+ task schema

```javascript
{
  id: "task-id",
  mode: "jumpplus.subscribe",
  account: {
    email: "user@example.test",
    password: "<transient>",
    imapEmail: "mailbox@example.test",
    imapPassword: "<transient>"
  },
  input: { payment: {
    cardNumber: "<transient>", expMonth: "02",
    expYear: "2030", securityCode: "<transient>"
  }},
  options: {
    createIfNeeded: false, allowExistingAccount: true,
    allowFinalSubmit: false, otpTimeoutMs: 120000,
    otpProvider: { serviceURL: "<configured>", apiKey: "<configured>" }
  }
}
```

Registration requires mailbox credentials unless a test-only mock confirmation
is explicit. Subscribe requires transient payment input. Passwords, mailbox
secrets, card data, and tokens are excluded from events/state/results and
cleared after execution. Safe results are atomically stored under
`/results/jumpplus`.

