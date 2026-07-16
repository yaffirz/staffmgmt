# Changelog 0021 — Phase 3: staff status changes (promote/demote/terminate)

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Status changes — promote, demote, terminate (+ reactivate). Each
  notifies the IT role (notification triggers #3/#4/#5). Adds the missing
  `employment_status` column.
- **Status:** Backend applied + running + verified via curl; frontend applied,
  `flutter analyze` clean. Pending a frontend restart (new files).

## Semantics
- **Promote / Demote** = change the employee's **position** (within their brand);
  action records `PROMOTION` / `DEMOTION`.
- **Terminate / Reactivate** = flip `employees.employment_status`
  ('active' | 'terminated').
- Every change: updates the employee, appends to `staff_status_log`, notifies IT
  (`recipient_role='IT'`, types STAFF_PROMOTED/DEMOTED/TERMINATED/REACTIVATED),
  writes an audit row.
- **Who:** Super Admin / Admin / HR (the "Status Changes" tile roles).

## Backend
- Migration: `employees.employment_status VARCHAR DEFAULT 'active'` (non-destructive).
  `ALLOWED_STATUS_ACTIONS` adds `REACTIVATION`.
- New `routes/status.py` (prefix `/api/v1/staff`):
  - `POST /{id}/status` — perform a change (validates position brand; blocks
    double-terminate).
  - `GET /{id}/status-log` — per-employee history (includes Phase 2b transfers).
  - `GET /status/feed` — recent changes across staff (capped 100).
- Staff-page response gains `position_id` + `employment_status`.

## Frontend
- Models: `staff_page` (+ positionId, employmentStatus), `status_log` (new).
- Service: `changeStatus`, `statusLog`, `statusFeed`.
- Staff page: header "Terminated" badge; an **Employment** section (Super Admin/
  Admin/HR only) — current position, Promote/Demote (position picker + reason),
  Terminate/Reactivate (reason), and a status **History** list.
- **Status Changes** dashboard tile → new `StatusFeedScreen` (feed across staff,
  each row → staff page). Wired for Super Admin/Admin + HR.
- Notifications: STAFF_PROMOTED/DEMOTED/TERMINATED/REACTIVATED render readably and
  clicking them opens the employee's staff page.

## Files touched
- backend: models.py, core/database.py, schemas/status.py (new),
  api/routes/status.py (new), schemas/notes.py, api/routes/notes.py, main.py
- frontend: models/staff_page.dart, models/status_log.dart (new),
  services/staff_service.dart, screens/employee_detail_screen.dart,
  screens/status_feed_screen.dart (new), screens/dashboard_screen.dart,
  models/app_notification.dart, widgets/notification_bell.dart

## Verification (curl)
- Migration: employment_status column present.
- HR promote emp 3 → Shift Supervisor; terminate; both produced IT notifications
  (STAFF_PROMOTED + STAFF_TERMINATED). AM blocked (403). status-log shows
  promote/terminate + the earlier transfer. Staff page reflects position + status.
  Reactivate cleaned up.

## Deployment
- Built: no. Backend restarted (migration ran). Frontend restart required (new files).
- Deployed to production: no

## Rollback
- Revert edits; remove status route/schema + status_feed/status_log. The
  employment_status column can remain.
