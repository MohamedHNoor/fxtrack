# Owner authentication

FXTrack has exactly one owner. Public registration does not exist: `/register`
returns 404, and the database allows only one row in `users` through the
`index_users_single_owner` unique index.

## Provisioning

Create the owner from an interactive terminal:

```sh
bin/rails "owner:create[owner@example.com]"
```

`EMAIL=owner@example.com bin/rails owner:create` also works, and with no email
the task prompts for one. Quote the bracket form in zsh.

The password (12 to 72 characters) is read twice without echo, so it never
appears in shell history, process lists or logs. Other tasks:

- `bin/rails owner:password` sets a new password and signs out every device.
  Use it if email delivery is unavailable.
- `bin/rails owner:prune_sessions` deletes expired session rows. Expired
  sessions are already rejected and deleted when presented, so this is
  housekeeping only.

## Routes

| Route | Purpose |
| --- | --- |
| `GET/POST /login` | Email and password login |
| `DELETE /logout` | Ends the current session |
| `DELETE /other_sessions` | Signs out every other device |
| `GET/POST /forgot-password` | Requests a reset email |
| `GET/PATCH /reset-password/:token` | Sets a new password |
| `GET /dashboard` | Private placeholder until M03 |

Every controller requires a session unless it calls
`allow_unauthenticated_access`. Only the landing, login and password pages do.

## Session policy

Owner decision (2026-10-11): a session expires after 7 days without activity
and always 30 days after login. The server enforces both limits on every
request and deletes an expired session when it is presented. Activity is
recorded at most hourly. The signed, HttpOnly, SameSite=Lax cookie expires at
the 30-day limit and is marked Secure in production.

Logout, "sign out other devices" and any password change revoke sessions by
deleting their rows. A new login resets the Rails session to prevent fixation.

Monitoring in later milestones runs only while at least one valid session
exists. With this policy, monitoring and alerts stop if the owner does not
open FXTrack for 7 days, and in any case 30 days after the last login.
`Session.active` is the eligibility query.

## Password reset

Requests receive the same response whether or not the address matches the
owner. The emailed link is signed, expires after 15 minutes and stops working
once the password changes. A successful reset signs out every device. The reset
page sets `Referrer-Policy: no-referrer` through a meta tag so the token is
not leaked to other sites.

In development, mail is written to `tmp/mails/` instead of being sent.
Production has no email provider yet; until one is chosen, reset email cannot
be delivered in production and `owner:password` is the recovery path.

## Rate limits

| Action | Limit |
| --- | --- |
| Login | 10 per 3 minutes per IP; 5 per 15 minutes per email |
| Reset request | 10 per 3 minutes per IP; 3 per hour per email |

Limits use the Rails cache store: Solid Cache in production, memory store in
development and test.

## Pending for production (M12)

- Choose an email provider and sender address (`ApplicationMailer` uses a
  placeholder `no-reply@example.com`).
- Enable `config.assume_ssl` and `config.force_ssl` once the Railway HTTPS
  setup is confirmed. The session cookie is already Secure in production.
