# Changelog 0015 — Phase 2b: My Cluster UI (Move / Request) + admin toggle UI

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Build the Area Manager "My Cluster" frontend on the Phase 2b backend
  (changelog 0004): store cards, Move staff, Request staff, and the admin
  "Area Managers can move staff" toggle UI.
- **Status:** Applied on disk; `flutter analyze` clean (1 pre-existing info note).
  Frontend-only against already-verified endpoints. Pending a full restart to load.

## What changed (frontend only)
- **Models:** `models/cluster.dart` (ClusterStore / ClusterStaffMember, with a
  `movable` helper = primary-here staff), `models/staff_search_result.dart`.
- **Service** (`staff_service.dart`): `cluster()`, `moveStaff(employeeId,
  toStoreId)`, `searchStaff(name)`, `requestStaff(employeeId, storeId)`,
  `getSetting(key)`, `updateSetting(key, value)`.
- **My Cluster screen** (`screens/my_cluster_screen.dart`, new): brand-grouped
  store cards with staff (managers/supervisors first, "Also covers" tag), plus per
  card:
  - **Move dialog** — pick a primary-here staffer + a destination store in the
    cluster; calls the move endpoint; surfaces the toggle-disabled 403 inline.
  - **Request dialog** — search all staff by name; each match shows brands/stores
    and a Request button that queues a request for this store.
- **Dashboard** (`dashboard_screen.dart`): the AM "My Cluster" tile now navigates
  to the screen (was a dead `_Dest.none` snackbar). Added a **Settings** tile for
  Super Admin / Admin.
- **Settings screen** (`screens/settings_screen.dart`, new): a switch for
  `area_managers_can_move` (get/patch via the settings endpoints), optimistic with
  revert-on-error. Satisfies standing rule 2 (toggle gets an admin control).

## Files touched
- staff_frontend/lib/models/cluster.dart — NEW
- staff_frontend/lib/models/staff_search_result.dart — NEW
- staff_frontend/lib/screens/my_cluster_screen.dart — NEW
- staff_frontend/lib/screens/settings_screen.dart — NEW
- staff_frontend/lib/services/staff_service.dart — cluster/move/search/request/settings
- staff_frontend/lib/screens/dashboard_screen.dart — My Cluster + Settings wiring

## Verification
- `flutter analyze` → clean apart from the pre-existing `withOpacity` info note.
- Backend endpoints already verified in changelog 0004.
- Pending full frontend restart, then in-browser:
  - As am_pizza: My Cluster shows Pizza Boys stores; move a staffer between stores;
    request a staffer for a store (check notification lands).
  - As superadmin: Settings → toggle off → am_pizza move is blocked with the
    inline "disabled by an administrator" message.

## Deployment
- Built: no. Frontend full restart required (new files).
- Deployed to production: no

## Rollback
- Remove the two new screens + two new models, revert staff_service.dart and
  dashboard_screen.dart edits.
