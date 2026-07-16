# Changelog 0025 — Admin mini-console (audit-log viewer)

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Build the admin mini-console required by standing rule #3 — a read
  view over `audit_logs`. The "Audit Logs" dashboard tile was a dead stub and
  there was no read endpoint (audit_logs was write-only).
- **Status:** Backend applied + running + verified via curl; frontend applied,
  `flutter analyze` clean. Pending a frontend restart (new files).

## Backend
- `GET /api/v1/audit-logs` (Super Admin / Admin only): recent entries newest first,
  resolved `user_name`, optional `?table=` filter, `?limit=` (default 200, max 500),
  and a human `summary` (e.g. "Updated employees #3"). New `routes/audit.py` +
  `schemas/audit.py`; registered in main.py.

## Frontend
- `models/audit_log.dart`, `services/staff_service.dart` `auditLogs({table})`.
- `screens/audit_logs_screen.dart`: a feed with NEW/UPD/DEL badges, summary, user +
  timestamp; table filter chips (All / Employees / Notes / Notifications / Users /
  Settings); tap a row for a before/after details dialog.
- Dashboard: the "Audit Logs" tile now opens it (`_Dest.auditLogs`).

## Files touched
- backend: schemas/audit.py (new), api/routes/audit.py (new), main.py
- frontend: models/audit_log.dart (new), services/staff_service.dart,
  screens/audit_logs_screen.dart (new), screens/dashboard_screen.dart

## Verification (curl)
- superadmin GET /audit-logs returned this session's rows (Updated employees,
  Created employee_additional_stores, notes, etc.) with user names + summaries;
  `?table=staff_notes` filtered correctly; it_test (non-admin) → 403.

## Deployment
- Built: no. Backend restarted. Frontend restart required (new files).
- Deployed to production: no

## Rollback
- Revert edits; remove audit route/schema + audit_logs_screen.dart/audit_log.dart.
