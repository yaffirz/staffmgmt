# Changelog 0066 — Outgoing email (SMTP) with an admin Email card

- **Timestamp:** 2026-09-22 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Turn on real email sending (planned provider: **Turbify**, Yahoo
  business mail, on the company domain). Manage the mail server from the admin
  page — an **Email card** to edit/change server settings without a redeploy —
  plus an **on/off toggle** and a **Send test email** button.
- **Status:** Applied (backend + frontend). Verified via API and in-browser.

## Background
Email was a **stub** — `core/email.py` only logged the message (registration's
confirmation link was the sole caller, and registration is off by default). There
were no SMTP settings anywhere.

## What changed
Email delivery is now real, configured entirely from the app and stored in
`app_settings` (so the server can be changed live).

### Backend
- **`core/app_settings.py`:** new `email_*` keys in `DEFAULTS`
  (`email_enabled`, `email_smtp_host`, `email_smtp_port`, `email_use_ssl`,
  `email_username`, `email_password`, `email_from`, `email_from_name`) plus an
  `EMAIL_SETTING_KEYS` allow-list (password excluded).
- **`core/email.py`:** real `smtplib` sender. `load_email_config()` reads the
  config from `app_settings`; `_deliver()` sends one plaintext message over
  SSL (465) or STARTTLS (587) and **raises** on failure; `send_email()` stays
  **best-effort** (never raises — logs when disabled/unconfigured or on error),
  so existing callers are unaffected. Opens its own DB session, so the
  `send_email(to, subject, body)` signature is unchanged.
- **`api/routes/email_admin.py` (new):** `GET/PUT /api/v1/email/config` and
  `POST /api/v1/email/test`, **Super Admin only** (SMTP credentials). The
  password is **write-only** — never returned; the read reports only
  `password_set`, and a blank password on update keeps the stored one. The test
  endpoint sends via `_deliver` and returns `{ok, detail}`, surfacing the real
  SMTP error instead of a 500; it works even while sending is disabled so it can
  be verified before going live. Config changes + test sends are audited (keys
  only, never secret values). Router registered in `main.py`.
- **`schemas/email.py` (new):** `EmailConfigRead` / `EmailConfigUpdate`
  (all-optional) / `TestEmailRequest` / `TestEmailResult`.

### Frontend
- **`screens/email_settings_screen.dart` (new):** Sending toggle; SMTP host,
  port, and an SSL/STARTTLS security dropdown (auto-nudges the port); username,
  password (obscured, "leave blank to keep"), From address, From name; **Save**;
  and a **Send test email** box that shows the result (with the SMTP error) in a
  dialog. Turbify hint at the bottom.
- **`services/staff_service.dart`:** `getEmailConfig`, `updateEmailConfig`,
  `sendTestEmail`.
- **`screens/admin_hub_screen.dart`:** new **Email** card ("SMTP server & test"),
  Super Admin only.
- **`docs/EMAIL.md` (new):** Turbify setup steps + how it works.

## Verification
- `python -m compileall` (backend) and `flutter analyze` (frontend) — clean;
  `flutter build web` — succeeds; backend hot-reloaded healthy.
- **API:** `GET config` returns defaults with `password_set:false`; `PUT`
  saves and the follow-up `GET` shows `password_set:true` with **no password
  field**; `POST test` with unreachable creds returned **HTTP 200
  `{ok:false, "SMTPServerDisconnected: ..."}`** (no 500); an **HR** token got
  **403** on the config. Placeholder values were then cleared back to defaults.
- **In-browser (superadmin):** the Email card appears in Admin; the screen shows
  all sections; a test send with empty config popped the expected "Fill in the
  SMTP host and From address first" dialog.

## How to turn it on
See `docs/EMAIL.md`. In short: Admin → Email → enter `smtp.bizmail.yahoo.com`,
port 465/SSL, your mailbox + **app-specific** password + From address → Save →
Send test → then flip **Email sending enabled** on.

## Rollback
- Revert the two new backend files + `app_settings.py`/`main.py` edits and the
  two new/one edited frontend files; delete `docs/EMAIL.md` and this changelog.
  The `email_*` settings rows (if any) can be left or deleted from `app_settings`.
