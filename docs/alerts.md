# Email alerts

FXTrack emails signal alerts through Resend's HTTPS API (`POST /emails`)
from `FXTrack <info@contact.mohamedhnoor.com>` to the owner's login address. Telegram
is deferred.

## Setup

1. Verify `contact.mohamedhnoor.com` in Resend (add its DNS records).
2. Create a Resend API key with sending access.
3. Add it to Rails credentials (`bin/rails credentials:edit`):

   ```yaml
   RESEND_API_KEY: re_...
   ```

4. Restart `bin/dev`. Development sends through Resend whenever the key is
   present; without it, mail is written to `tmp/mails/`. Production always
   uses Resend and reads link hosts from `APP_HOST`.
5. On `/alerts`, turn on email notifications and use "Send test email".

## Preferences (`/alerts`)

Email is off until the owner saves preferences. Events:

| Event | Default | Sent when |
| --- | --- | --- |
| New qualifying signal | on | A strategy creates a BUY or SELL signal |
| Signal expired | off | A signal reaches its expiry |
| Signal invalidated | off | A newer candle breaks the stop or entry tolerance, or the pair is disabled |

## Delivery

A signal event creates one `signal_deliveries` row (unique per signal, channel
and event) and queues `SignalAlertJob`. At dispatch the job rechecks:

1. email alerts and that event are still enabled;
2. a valid owner session exists;
3. the pair is still enabled;
4. for new-signal alerts, the signal is still active and unexpired.

A failed check records `suppressed` with the reason instead of sending. A sent
delivery is never sent again. Timeouts and connection errors retry up to three
attempts with growing waits, then record `failed` with the error class.
Authentication or rejected-message errors fail immediately. Failures appear on
`/alerts` (recent deliveries) and on each signal card; error messages and keys
are never stored.

Signal sends hold a database row lock so overlapping workers cannot send the
same delivery concurrently. Before the first HTTP request, the exact message
payload and first-attempt timestamp are stored. Retries reuse that payload and
a stable delivery-specific `Idempotency-Key`. HTTP 429, 5xx, concurrent-key
responses and transport failures retry; rejected payloads/credentials fail.
Retries at or beyond 24 hours from the first attempt fail visibly instead of
risking a duplicate outside Resend's documented idempotency window.
See [Resend idempotency documentation](https://resend.com/docs/dashboard/emails/idempotency-keys).
Development file delivery and test delivery continue using Action Mailer.

Password-reset emails and the manual test email still use the configured
Action Mailer delivery method (Resend SMTP when configured).
