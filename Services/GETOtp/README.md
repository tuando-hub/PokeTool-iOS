# GETOtp service

This hardened IMAP/MIME boundary is not embedded in iOS. Use Node.js 20+, run
`npm ci`, set `GETOTP_API_KEY`, and start with `npm start`. It binds localhost;
production must terminate TLS at a trusted HTTPS reverse proxy.

`POST /v1/otp/wait` accepts an operation ID, mailbox credential, recipient,
mode, received-after timestamp and bounded timing. `DELETE
/v1/operations/:id` cancels. The service verifies IMAP TLS, opens INBOX
read-only, does not mark/delete mail, filters old and wrong-recipient messages,
deduplicates UIDs, hashes message IDs and closes the connection.

Gmail and iCloud/Me/Mac are built in. Other providers need explicit mapping.
Yahoo is not assumed. CI uses `npm test` and never contacts a mailbox.
