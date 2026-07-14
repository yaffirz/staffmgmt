# Changelog 0013 — Store drilldown + notification click-through

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Clicking a notification should mark it read AND navigate to the
  relevant place — for a staff move/request, the store where the staff was added.
  Keep "Mark all read". Chosen destination: a new store drilldown screen.
- **Status:** Applied on disk; `flutter analyze` clean (1 pre-existing info note).
  Backend verified via curl. Frontend pending a full restart to load new files.

## What changed

### Backend (verified)
- `GET /api/v1/stores/{store_id}/staff` (Super Admin / Admin / HR) — returns the
  store (id/name/brand) and its staff: those whose PRIMARY store is here, plus
  those covering it via an additional-store link (`also_covers: true`), sorted
  managers/supervisors first. 404 for a missing store.
- New `routes/stores.py` + `schemas/stores.py`; registered in `main.py`.
- Verified: `GET /stores/3/staff` returns Chaguanas with emp 3 (primary),
  emp 4 (also_covers), emp 2 (primary); `GET /stores/999/staff` → 404.

### Frontend
- `models/store_staff.dart` — StoreStaff / StoreStaffMember.
- `services/staff_service.dart` — `staffAtStore(storeId)`.
- `screens/store_drilldown_screen.dart` — lists staff for a store; the deep-linked
  employee (`highlightEmployeeId`) is highlighted with a "Recently added" chip;
  additional-store staff get an "Also covers" chip.
- `models/app_notification.dart` — `targetStoreId` / `targetStoreName` /
  `targetEmployeeId` derived from the payload (STAFF_MOVED → to_store_*,
  STAFF_REQUESTED → requested_store_*).
- `widgets/notification_bell.dart` — clicking a notification now marks it read
  (updating the badge), closes the menu, and navigates to the store drilldown for
  its target, highlighting the employee. "Mark all read" unchanged. Also carries
  the 0012 hidden-badge fix (loads with this restart).

## Caveats
- Recipients today are Admin / Super Admin (the notifications target role 'Admin').
  The identical flow will serve the "IT technician" once the IT role + multi-role
  work is built — no change needed here beyond who receives the notification.

## Files touched
- backend/app/schemas/stores.py — NEW
- backend/app/api/routes/stores.py — NEW
- backend/app/main.py — register stores router
- staff_frontend/lib/models/store_staff.dart — NEW
- staff_frontend/lib/screens/store_drilldown_screen.dart — NEW
- staff_frontend/lib/models/app_notification.dart — target getters
- staff_frontend/lib/services/staff_service.dart — staffAtStore + import
- staff_frontend/lib/widgets/notification_bell.dart — click → mark read + navigate

## Verification
- Backend: compileall clean; endpoint returns correct data + 404 (done).
- Frontend: `flutter analyze` clean apart from the pre-existing `withOpacity` note.
- Pending: full frontend restart (new files → hot reload insufficient), then
  in-browser confirm: click a "Staff moved" notification → drilldown opens on the
  store with the employee highlighted; console clean at count 0 (0012).

## Deployment
- Built: no. Backend restarted (volume + reload). Frontend needs a full restart.
- Deployed to production: no

## Rollback
- Remove stores route/schema + drilldown screen/model, revert main.py,
  staff_service.dart, app_notification.dart, notification_bell.dart edits.
