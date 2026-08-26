# Changelog 0056 — Require password change at next login

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add a checkbox on the user create/edit form to force a user to change
  their password the next time they log in (account-security hygiene).
- **Status:** Applied. Backend flow **verified end-to-end** via API
  (create-flagged → login/`/me` report it → change-password clears it and the new
  password logs in → admin re-flag). `compileall` + `flutter analyze` clean;
  built + deployed. Frontend forced-change screen not browser-tested (pane not
  displayable this session) — wiring is straightforward and analyze-clean.

## Backend
- `models.py` — `Users.must_change_password` bool (default false, non-destructive
  migration in `database.py`).
- `schemas/user.py` — `UserCreate.must_change_password` (default false),
  `UserUpdate.must_change_password` (optional), `UserRead.must_change_password`.
- `schemas/auth.py` — `must_change_password` on `TokenResponse` and `CurrentUser`;
  new `ChangePasswordRequest`.
- `api/routes/users.py` — create/update set the flag; `_read` returns it.
- `api/routes/auth.py`:
  - `login` returns the flag; **`/me`** now reads it live from the DB (so it
    reflects a change made after the token was issued).
  - **`POST /api/v1/auth/change-password`** `{new_password}` — the signed-in user
    sets their own new password and the flag is cleared. Any authenticated role.

## Frontend
- `models/auth_user.dart` / `models/user_account.dart` — carry
  `mustChangePassword`; `AuthUser.copyWith`.
- `services/auth_service.dart` — `changePassword()`; `staff_service.dart` —
  `createUser`/`updateUser` send `must_change_password`.
- `state/auth_provider.dart` — `changePassword()` clears the flag locally so the
  gate proceeds.
- **`screens/force_password_change_screen.dart`** (new) — new + confirm password
  (with reveal), blocks the app until set; a Log-out escape hatch.
- `screens/root_gate.dart` — when authenticated and `mustChangePassword`, shows
  the forced screen ahead of maintenance / home.
- `screens/users_screen.dart` — **"Require password change at next login"**
  checkbox on create/edit, prefilled when editing.

## Rollback
- Revert the edits + delete `force_password_change_screen.dart`. The
  `must_change_password` column is additive and harmless if unused.
