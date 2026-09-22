# Changelog 0067 — Per-user email opt-in + self-service password reset

- **Timestamp:** 2026-09-22 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** (1) Control **who receives** platform emails — a toggle per account
  in Users & Roles. (2) A **password-reset page** users reach via a **timed link
  from email**, which lets them set a new password without logging in.
- **Status:** Applied (backend + frontend). Verified via API and in-browser.
- **Follows:** 0066 (SMTP sending). Email must be enabled there for reset mail to
  actually send.

## Feature 1 — per-user "Receives platform email"
- **Backend:** new `users.email_opt_in` (bool, default true; non-destructive
  `ADD COLUMN IF NOT EXISTS`). Threaded through `UserCreate/Update/Read`, the
  users route (`create`, `update`, `_read`), and audited on change.
- **Frontend:** a **"Receives platform email"** switch in the Users & Roles form;
  `UserAccount.emailOptIn` + `createUser/updateUser` params.
- When off (or no email / suspended), the account is skipped by platform email
  (currently: password resets).

## Feature 2 — forgot / reset password via timed link
- **New table `password_reset_tokens`** (user_id, token, `expires_at`, `used`) —
  created by `create_all`. Tokens are single-use and expire after **60 minutes**.
- **New endpoints** (`routes/auth.py`, all unauthenticated):
  - `POST /api/v1/auth/forgot-password` `{identifier}` — matches a username or
    email (case-insensitive); if the account exists, has an email, is opted in
    and not suspended, invalidates old tokens, issues a fresh one, and emails a
    link. **Always returns the same neutral message** so it can't probe which
    emails are registered. No-op (still neutral) otherwise.
  - `GET /api/v1/auth/reset-password/validate?token=` — `{valid}` so the screen
    can show "expired" without submitting.
  - `POST /api/v1/auth/reset-password` `{token, new_password}` — validates the
    token (unused + unexpired), sets the password (bcrypt), clears
    `must_change_password`, marks the token used. 400 on bad/expired token, 422
    if the password is < 6 chars.
- **Link building:** `{app_base_url or request.base_url}/?reset_token=…`. New
  `app_base_url` setting (blank = derive from the request) is editable on the
  **Admin → Email** page as **"Public site URL (for links in emails)"** (added to
  the email config read/update API).
- **Frontend:**
  - **Login screen:** a **"Forgot password?"** link → `ForgotPasswordScreen`
    (enter username/email → neutral "check your email" confirmation).
  - **`ResetPasswordScreen`** (new): validates the token, then new-password +
    confirm with success / invalid-link states.
  - **`RootGate`** captures a `reset_token` query param once at startup and shows
    the reset screen (ahead of the login/auth flow); `onDone` drops the token and
    returns to normal routing.
  - `StaffService.forgotPassword / validateResetToken / resetPassword`.

## Verification
- `python -m compileall` + `flutter analyze` — clean (only pre-existing infos);
  `flutter build web` — succeeds; backend hot-reloaded and created the table.
- **API (throwaway users, cleaned up):** forgot → neutral; token row created;
  validate → `{valid:true}`; reset → success; login with the **new** password →
  200; token reuse → 400 (single-use); an **opted-out** user gets **no token**;
  the opt-in toggle round-trips via create/PATCH.
- **In-browser:** opened `/?reset_token=…` → reset screen → set password →
  "Password updated" → the user could log in with the new password (DB confirmed,
  token `used=true`); the login **Forgot password?** link → neutral confirmation;
  the Users & Roles form shows the **Receives platform email** toggle.

## Security notes
- Reset tokens are random (`secrets.token_urlsafe(32)`), single-use, 60-min
  expiry, and stored raw (consistent with the registration email token, on a
  private DB). Hashing tokens at rest is a possible hardening follow-up.
- No rate limiting on forgot-password yet (neutral responses limit its value as
  an oracle); a limiter is a candidate follow-up.

## Rollback
- Revert the backend + frontend edits and the two new frontend screens; delete
  this changelog. The `password_reset_tokens` table and `users.email_opt_in`
  column can be left (unused) or dropped.
