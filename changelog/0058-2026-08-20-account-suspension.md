# Changelog 0058 — Account suspension (block login + live sessions, reversible)

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A way to **suspend** a user account instead of deleting it — disables
  access while keeping the account and all its history, and is reversible. Also
  answers the earlier delete limitation (suspend a user who authored content
  rather than hard-deleting).
- **Status:** Applied and **verified end-to-end** — backend via API (suspend
  cuts off a live session on its next request; suspended login blocked with a
  message; reactivate restores; self-suspend guarded) and in the browser (toggle
  in the edit form with prefill, "Suspended" badge in the list, reactivate clears
  it). `compileall` + `flutter analyze` clean; built + deployed.

## Model
- `Users.suspended` bool (default false, non-destructive migration).

## Enforcement (immediate cut-off)
- `api/deps.py` `get_current_user` now reads the user (added a `session` dep) and
  **rejects a suspended account on every request (403)** — so suspending someone
  ends their active session on its next call, not just future logins.
- `api/routes/auth.py` `login` — a suspended account gets **403** "This account
  is suspended. Contact an administrator." (after the credential check).

## Admin controls
- `schemas/user.py` — `suspended` on `UserCreate`/`UserUpdate`/`UserRead`.
- `api/routes/users.py` — create/update set it; `_read` returns it; **you cannot
  suspend your own account** (400 guard, mirrors the role/delete self-guards).
- `screens/users_screen.dart` — an **"Account suspended"** switch in the edit
  form (hidden for your own account), and a red **"Suspended"** badge on the
  user's row in the list.
- `models/user_account.dart`, `services/staff_service.dart` — carry/send the flag.

## Notes
- Suspended users stay in the list (marked), not hidden.
- Mid-session, a suspended user's requests start returning 403; a page reload
  then routes them to login (auto-login's `/me` check fails cleanly). A global
  "kick to login on 403" handler could make that instant without a reload —
  left as a follow-up.

## Rollback
- Revert the edits. The `suspended` column is additive and harmless if unused.
