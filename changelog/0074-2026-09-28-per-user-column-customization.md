# Changelog 0074 — Per-user adjustable employee-list columns (saved)

- **Timestamp:** 2026-09-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Make the employee-list columns **adjustable per user** and **save the
  layout**, available to **admins** and **Karisma** specifically (a fit-on-screen
  option — hide the columns you don't need).
- **Status:** Applied (backend + frontend). Core verified via API + in-browser.

## What changed
### Backend
- **New `user_preferences` table** (id, user_id, pref_key, value JSONB,
  updated_at; unique per user+key) — created by `create_all`. Self-service
  endpoints (`routes/preferences.py`, registered in `main.py`):
  `GET/PUT /api/v1/me/preferences/{key}` — each user reads/writes only their own
  rows.
- **`/auth/me`** now returns **`can_customize_columns`**: true for
  Super Admin / Admin, or if the username is in the **`column_customizers`**
  setting (comma-separated, case-insensitive). New setting defaults to
  **`karisma`**.
- Schema: `CurrentUser.can_customize_columns`.

### Frontend
- **`models/auth_user.dart`:** parse `can_customize_columns`.
- **`services/staff_service.dart`:** `getPreference` / `setPreference`.
- **`screens/employees_list_screen.dart`:**
  - A **Columns** button in the app bar (only when `canCustomizeColumns`) opens a
    checklist of the 14 toggleable columns (`kToggleableColumns`). Reviewed / Name
    / Actions are always shown. "Show all" resets; "Apply" saves.
  - Hidden columns are dropped from **both** the header and every row (kept in
    sync so column and cell counts always match). The saved layout is loaded on
    open and re-applied. Persisted under the `employee_columns` preference key.
- **`screens/settings_screen.dart`:** a **"Who can customize employee columns"**
  field (edits the `column_customizers` setting) — standing rule #2.

## Verification
- `python -m compileall` + `flutter analyze` — clean (only the 2 pre-existing
  `use_build_context_synchronously` infos); `flutter build web` — ok; backend
  hot-reloaded and created the table.
- **API:** `/auth/me` → `can_customize_columns: true` for superadmin;
  preferences `GET` (null) → `PUT` → `GET` round-trips; `karisma` matches the
  default setting.
- **In-browser:** with a saved layout hiding 8 columns, the list re-rendered with
  only the kept columns (Reviewed, Name, Store, Position, Email, Phone, Pay rate,
  Additional stores, Actions) — no crash, tints intact, row fits the screen. The
  **Columns** button shows for the admin. (The picker dialog itself couldn't be
  click-tested through the automated browser — a coordinate-hit issue on the small
  app-bar icon in the scaled canvas — but it is standard, analyze-clean code
  mirroring the verified review-flag dialog; the underlying save/load/hide path is
  confirmed.) Test preference cleared afterward.

## Notes
- Scope is **show/hide** columns (the direct fit-on-screen lever). Column
  **reorder / resize** is a natural follow-up (the pref already stores a list, so
  it's forward-compatible).
- The full wide table is unchanged for everyone else; only permitted users get the
  Columns control.

## Rollback
- Revert the backend + four frontend edits and delete `routes/preferences.py` +
  this changelog. The `user_preferences` table and `column_customizers` setting
  can be left unused.
