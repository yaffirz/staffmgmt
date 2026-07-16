# Changelog 0022 — Cross-store assignments (Phase 2b close-out, trigger #2)

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** An Area Manager assigns an existing cluster staffer to another store
  in their cluster (additional, accumulative — primary unchanged). Notifies IT
  (notification trigger #2). Wires the dead "Cross-store Assignments" tile.
- **Status:** Backend applied + running + verified via curl; frontend applied,
  `flutter analyze` clean. Pending a frontend restart (new file).

## Backend
- `POST /api/v1/cluster/employees/{id}/assign-store` (Area Manager only), body
  `{store_id}`:
  - Validates the staffer is in the AM's cluster and the target store is too;
    rejects the primary store and duplicates.
  - Adds an `employee_additional_stores` link (stores accumulate; only removed on
    termination, per the agreed model).
  - Notifies IT (`recipient_role='IT'`, type `STAFF_ASSIGNED`) + audit row.
- Schemas: `AssignStoreRequest`, `AssignStoreResult`.

## Frontend
- Service: `assignStore(employeeId, storeId)`.
- `screens/cross_store_screen.dart` (new): loads the cluster, builds the distinct
  staff set, and offers pick-staff → pick-target-store (cluster stores they're not
  already in) → Assign. Shows the staffer's current stores.
- Dashboard: the AM "Cross-store Assignments" tile now opens it (`_Dest.crossStore`).
- Notifications: `STAFF_ASSIGNED` renders readably and deep-links to the store
  drilldown (highlighting the employee).

## Files touched
- backend: schemas/cluster.py, api/routes/cluster.py
- frontend: services/staff_service.dart, screens/cross_store_screen.dart (new),
  screens/dashboard_screen.dart, models/app_notification.dart

## Verification (curl)
- am_pizza assigns Test UI 2 (emp 2) → Chaguanas (store 3): 201; IT received
  STAFF_ASSIGNED ("Test UI 2 -> Chaguanas by am_pizza"); the additional-store link
  exists; cluster GET shows the staffer at Chaguanas as "also covers".
- Negatives: assigning to the primary store, to a duplicate, and to a
  non-cluster store all rejected (400).

## Deployment
- Built: no. Backend restarted. Frontend restart required (new file).
- Deployed to production: no

## Rollback
- Revert edits; remove cross_store_screen.dart + the assign-store endpoint/schemas.
