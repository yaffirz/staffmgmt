# Changelog 0024 — Trigger #1: marking reviewed notifies the brand's AM(s)

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Replace the original delayed ("1 hour later") trigger. When an employee
  row is marked **reviewed** (the existing flag — no new "account complete"
  concept), immediately notify the respective Area Manager(s) with a message asking
  them to check the staffer in about an hour. No scheduler needed.
- **Status:** Backend applied + running + verified via curl; frontend applied,
  `flutter analyze` clean. Frontend rendering loads on next hot restart.

## Behaviour
- On `PATCH /api/v1/employees/{id}/reviewed` transitioning `false -> true`, notify
  every Area Manager whose brands include the employee's (primary store's) brand —
  one notification per AM user (`recipient_user_id`), type `STAFF_REVIEWED`,
  payload `{employee_id, employee_name, store_name, by_username}`.
- Fires immediately; the message text says "…please check them at <store> in about
  an hour." Only fires on the false→true transition (re-marking true does nothing).
- The reviewed flag itself is unchanged and already visible in the Employees list —
  no display changes needed (per the agreed simplification).

## Frontend
- `models/app_notification.dart`: `STAFF_REVIEWED` title/body; `opensStaffPage` so
  clicking it opens the employee's staff page (AM-accessible for their cluster).

## Files touched
- backend/app/api/routes/employees.py — `_notify_managers_reviewed` + hook in
  `set_reviewed` (imports AreaManagers/AreaManagerBrands/Notifications)
- frontend: staff_frontend/lib/models/app_notification.dart

## Verification (curl)
- IT marked emp 2 (Test UI 2, Pizza Boys) reviewed → am_pizza received
  STAFF_REVIEWED ("Test UI 2 @ San Fernando by it_test"). Re-marking reviewed=true
  did NOT create a duplicate (count stayed 1).

## Deployment
- Built: no. Backend restarted. Frontend hot restart to load the rendering.
- Deployed to production: no

## Rollback
- Revert the employees.py + app_notification.dart edits.
