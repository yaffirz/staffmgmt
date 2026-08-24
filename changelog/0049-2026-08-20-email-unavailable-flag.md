# Changelog 0049 — New-hire "email currently unavailable" + amber HR flag

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Email is mandatory on the new-hire form, but sometimes it isn't
  available at hire time. Add an "email currently unavailable" checkbox so the
  hire can go through; flag such rows **amber** in the employee list for HR to
  supply an email; and when someone (e.g. IT) marks the row reviewed, pop an
  **"Email not valid"** dialog. The amber flag clears once an email is added.
- **Status:** Applied and **verified end-to-end** — backend curl-tested
  (create/update/enforcement/toggle) and the full UI flow driven in a browser
  (wizard checkbox disables/clears email; amber row; "Email not valid" dialog on
  review; auto-clear to green after an email is saved). `compileall` clean;
  `flutter analyze` clean (only the file's two pre-existing lints). Built +
  deployed via `flutter build web`.

## Behaviour
- **HR alert = amber row only** (no bell notification, by request).
- **Auto-clear**: the moment a valid email is saved, `email_pending` → false and
  the amber highlight drops.
- Gated by a Super-Admin/Admin toggle `email_unavailable_enabled` (default on),
  per standing rule #2. When off, an email is always required again.

## Backend
- `models.py` — `Employees.email_pending` bool (default false).
- `core/database.py` — non-destructive migration
  (`ADD COLUMN IF NOT EXISTS email_pending BOOLEAN NOT NULL DEFAULT false`).
- `core/app_settings.py` — `email_unavailable_enabled` default `"true"`.
- `schemas/employee.py` — `EmployeeCreate.email_pending` (input) and
  `EmployeeRead.email_pending` (output).
- `api/routes/employees.py`:
  - `_email_pending()` — effective flag: only when no email is given, the client
    asked for it, and the feature is on; an email that is present always clears it.
  - `_validate_config_required(..., allow_email_missing=...)` — waives the email
    requirement when creating "email pending".
  - `create_employee` / `update_employee` set `email_pending`; update auto-clears
    it when an email is provided.
  - `_enrich` + `list_employees` return `email_pending`.
  - **`GET /api/v1/employees/form-flags`** (write roles) — returns
    `email_unavailable_enabled` so the wizard (HR/IT) can decide whether to show
    the checkbox without the admin-only settings endpoint.

## Frontend
- `models/employee.dart` — `emailPending`.
- `services/staff_service.dart` — `employeeFormFlags()`.
- `screens/new_hire_wizard_screen.dart` — loads the flag; a **"Email currently
  unavailable"** `CheckboxListTile` under the email field (shown only when email
  is required and the toggle is on). Checking it clears + disables the email
  field, waives validation, and submits `email_pending: true`. Prefilled when
  editing an already-pending staffer.
- `screens/employees_list_screen.dart` — amber row tint for `emailPending`
  (takes precedence over the reviewed-green), an "Email pending" cell indicator,
  and an **"Email not valid"** dialog shown to the reviewer when an email-pending
  row is marked reviewed.
- `screens/settings_screen.dart` — a **New-hire form** section with the
  `email_unavailable_enabled` switch.

## Deployment
- Backend hot-reloaded (migration ran on reload; column confirmed). Frontend
  built with `flutter build web`, served same-origin + tunnel (`no-store`).
  Hard-refresh once to drop any old in-memory bundle.

## Rollback
- Revert the edits. The `email_pending` column is additive and harmless if unused.
