# Pokemon testing

JavaScriptCore tests verify registry/task schema, multi-signal pages, OTP
configuration, redaction, event prefix and result parsing. Node tests cover
provider selection and mail parsing. CI never contacts Pokemon Center, a
mailbox, or a production OTP server.

The Debug Dashboard Pokemon action runs an entry/descriptor self-test. Before
production device use, revalidate real titles/selectors for all modes, configure
the HTTPS OTP service, test Gmail/iCloud app passwords, and run Buy with
`allowFinalSubmit: false` before any explicit final-submit test.
