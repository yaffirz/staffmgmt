# 0093 — "Move to unemployed" action on the Area Dashboard

**Date:** 2026-11-02

## What

Each staff row on the **Area Dashboard** gets a per-row action (⋮ →
**Move to unemployed**) that moves the staffer to the unemployed group —
i.e. sets `employment_status = 'terminated'` — so managers can do this from
their own dashboard without going through the admin Status Changes screen.

## Why

Managers needed to retire a staffer directly from the dashboard they already
use. The existing termination endpoint (`POST /staff/{id}/status`,
`TERMINATION`) is gated to Super Admin / Admin / HR and isn't cluster-scoped, so
Ops/Area Managers couldn't use it.

## Backend

- **`routes/platforms.py`** — new `POST /api/v1/employees/{id}/unemployed`
  (roles = the dashboard's `MANAGE_ROLES`). Scoped to the caller's cluster via
  `_assert_can_edit_employee`. Sets `employment_status='terminated'`, appends a
  `TERMINATION` row to `staff_status_log`, notifies IT (`STAFF_TERMINATED`), and
  audits — mirroring the Status-Changes termination so the Status Changes feed
  and per-employee history stay consistent. 400 if already unemployed.
- **Toggle** `managers_can_terminate` (default **on**, standing rule #2):
  Ops/Area Managers are gated by it; admin roles (Super Admin/Admin/IT/HR)
  always may. The dashboard response now carries `can_unemploy` (admin OR toggle
  on) so the button only shows when permitted.

## Frontend

- **`area_dashboard_screen.dart`** — a ⋮ menu on each staff row (shown when
  `canUnemploy`) with **Move to unemployed**; a confirm dialog, then the staffer
  drops off the (active-only) dashboard. `platform.dart` gains
  `AreaDashboard.canUnemploy`; `StaffService.moveEmployeeUnemployed`.
- **Settings** — "Managers can move staff to unemployed" switch under *Area
  Manager permissions* (`managers_can_terminate`).

## Verified

- `python -m compileall` + `flutter analyze` / `flutter build web` clean.
- API: admin dashboard returns `can_unemploy: true`; the endpoint is registered
  and validates the employee (404 for a bogus id before any mutation). The
  mutation path reuses the already-proven termination flow (status log + IT
  notification + audit); it is reversible via Status Changes → Reactivate.
- The in-browser button is a standard `PopupMenuButton` (the preview pane was
  behind another window at screenshot time, so not captured).

## Note

Reversible: an admin/HR reactivates from **Status Changes** (sets
`employment_status` back to active), exactly as for any other termination.
