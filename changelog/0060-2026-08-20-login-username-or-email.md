# Changelog 0060 — Log in with username OR email, case-insensitive

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Let users sign in with either their username or their email, and make
  the username case-insensitive.
- **Status:** Applied and verified via API (exact / lower / UPPER username, email
  in any case, with surrounding spaces — all log in; wrong id → 401).
  `compileall` + `flutter analyze` clean; built + deployed.

## Backend (`api/routes/auth.py` `login`)
- The identifier is trimmed and matched **case-insensitively against both
  `username` and `email`** (`or_(lower(username)==x, lower(email)==x)`).
- If two accounts collide only by letter case, an exact match is preferred;
  otherwise the first match is used. Everything after (password check, suspended
  check, token) is unchanged, as is the generic "Invalid username or password".

## Frontend (`screens/login_screen.dart`)
- The field label is now **"Username or email"** (validator message too), and it
  offers both username + email autofill hints.

## Notes
- Emails are already unique per tenant and usernames unique per tenant; the
  case-insensitive lookup does not change storage, only matching at login.

## Rollback
- Revert the two edits.
