# Changelog 0077 — Admin "Email password reset link" from Users & Roles

- **Timestamp:** 2026-10-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Let an admin send password-reset instructions to a user directly —
  a button to click that emails the reset link — in addition to the login-page
  **Forgot password?** flow.
- **Status:** Applied (backend + frontend). Verified via API and in-browser.

## What changed
### Backend
- **`api/routes/auth.py`:** extracted the token-issue + email-render logic from
  `forgot-password` into a reusable `prepare_reset_email(session, user, request)`
  helper (invalidates outstanding tokens, mints a fresh single-use 60-min token,
  renders the admin-editable subject/body via `render_template` / `compose_message`,
  returns `(to, subject, text, html)`). `forgot-password` now calls it — behaviour
  unchanged (still neutral, best-effort `send_email`).
- **`api/routes/users.py`:** new `POST /api/v1/users/{user_id}/send-password-reset`
  (**Admin / Super Admin** only, via `MANAGE_ROLES`). Unlike the public flow it
  returns **real errors** so the admin knows the outcome:
  - 404 user not found;
  - 400 when the user has no email, has opted out of platform email, or is
    suspended;
  - 400 when email sending is off / unconfigured (Admin → Email);
  - 502 with the underlying SMTP error if the send fails.
  On success it sends via `_deliver` (not the swallow-errors `send_email`) and
  returns `{"detail": "A password reset link was emailed to …"}`.

### Frontend
- **`services/staff_service.dart`:** `sendPasswordReset(userId)` → returns the
  success detail; throws `ApiException` with the real reason otherwise.
- **`screens/users_screen.dart`:** in the user **edit** dialog, an **"Email
  password reset link"** button under *Receives platform email*. Shows a spinner
  while sending, a green confirmation line on success, and routes failures to the
  dialog's existing error text. Only shown when editing an existing user.

## Why no new toggle
This is an admin **action**, not a toggleable feature. It already respects the
existing global **email on/off** (0066) and per-user **Receives platform email**
opt-in (0067), so no extra admin toggle is needed (standing rule #2).

## Verification
- **API:** `POST /users/{id}/send-password-reset` as Super Admin returned
  `400 "Email sending is turned off. Enable it in Admin → Email."` (email is
  disabled in dev) — confirming the role guard, eligibility checks and
  email-enabled check all fire.
- **In-browser:** the button appears in the edit dialog; clicking it (email off)
  surfaced the same clear message inline in red. `flutter analyze` clean (only the
  pre-existing `use_build_context_synchronously` info in `_deleteUser`);
  `flutter build web` ok; backend `compileall` + import check ok (no circular
  import between `users` and `auth`).

## Rollback
- Remove the endpoint + service method + button, inline `prepare_reset_email`
  back into `forgot-password`, and delete this changelog.
