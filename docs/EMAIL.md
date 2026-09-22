# Outgoing email (SMTP)

The platform can send email (currently: registration-confirmation links) through
your own SMTP server. Everything is configured from the app — **Admin → Email**
(Super Admin only) — and stored in `app_settings`, so you can change providers or
credentials without a redeploy.

## Set it up (Turbify / Yahoo business mail)

1. Sign in as a **Super Admin** → **Admin → Email**.
2. Fill in **SMTP server**:
   - **SMTP host:** `smtp.bizmail.yahoo.com` (Turbify business mail).
     *(Consumer Yahoo is `smtp.mail.yahoo.com` — different. Confirm the exact
     host in your Turbify control panel.)*
   - **Port / Security:** `465` + **SSL** (recommended), or `587` + **STARTTLS**.
3. Fill in **Credentials & sender**:
   - **Username:** your full mailbox address, e.g. `noreply@yourcompany.com`.
   - **Password:** a **Turbify/Yahoo app-specific password** — generate one in the
     Yahoo/Turbify Account Security page. The normal login password is rejected
     for third-party SMTP when 2-step verification is on. *(Stored write-only:
     it's saved but never shown again; leave the field blank to keep it.)*
   - **From address:** a **real mailbox on your domain** (Yahoo/Turbify reject
     sending "from" an address you don't own). Usually the same as the username.
   - **From name:** the display name, e.g. `Staff Portal`.
4. **Save settings.**
5. **Send a test email** to yourself (bottom of the page). This works even while
   sending is off, and shows the exact SMTP error if something is wrong.
6. Once the test arrives, turn **Email sending enabled** on and Save.

## Deliverability (SPF / DKIM)

Because mail relays through Yahoo's own servers on your own domain, SPF is
normally already set when Turbify hosts your domain. To avoid the spam folder,
confirm in your Turbify DNS/email panel that **SPF** is present and enable
**DKIM** if offered. The **From address must be a real mailbox** on the domain.

## How it works (for developers)

- Config keys live in `app/core/app_settings.py` (`email_*`), read/written by the
  Super-Admin API in `app/api/routes/email_admin.py`
  (`GET/PUT /api/v1/email/config`, `POST /api/v1/email/test`).
- `app/core/email.py` is the single sender. `send_email(to, subject, body)` is
  **best-effort** (never raises; logs on failure or when disabled/unconfigured),
  so callers like registration are unaffected if email isn't set up. `_deliver`
  does the real `smtplib` work and raises; the test endpoint uses it to surface
  errors.
- The SMTP password is stored in `app_settings` and never returned by the API
  (the read reports only `password_set`). It is admin-only data on a private DB;
  if you later want it encrypted at rest, that's a follow-up.
