# Changelog 0043 — Country management (add countries for the staff form)

- **Timestamp:** 2026-08-04 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add a way to add/manage additional countries under the Brands &
  Stores hub (alongside Brands and Positions). The list feeds the Country field
  on the staff (new-hire) registration form that HR and other write-roles use.
- **Status:** Applied. Backend verified end-to-end against the running API
  (create / duplicate-409 / rename / delete-204, unauth-403); `compileall` clean;
  `flutter analyze` clean (only the same info-level lints the sibling
  `brands_list_screen.dart` already carries). **Not built/deployed** — frontend
  needs `flutter build web` + a deploy, which is a separate operator step.

## Background
The Country field was **already wired** into the new-hire form
(`new_hire_wizard_screen.dart`): it reads `GET /api/v1/countries`, shows by
default (`_shown('country_id')` defaults true), and is toggle-able to required in
**Form Settings → Employee form**. The only missing piece was a way to **add**
countries — the API was read-only and only "Trinidad" was seeded. This change
adds the write side + a management screen. No form rewiring was needed.

## What changed
Country CRUD mirroring the existing Brand endpoints/screen, gated to
Super Admin / Admin (`ORG_ROLES`). Selecting a country on the staff form remains
available to every role that uses that form. Bulk CSV import was intentionally
**excluded** (single add/edit/delete only, per request).

Countries remain a **global** lookup (no `tenant_id`) — unchanged table, no DB
migration.

## Files touched
- `backend/app/schemas/lookups.py` — add `CountryCreate`, `CountryUpdate`.
- `backend/app/api/routes/lookups.py` — add:
  - `POST /api/v1/countries` — create; trims, rejects empty, case-insensitive
    duplicate → 409.
  - `PATCH /api/v1/countries/{id}` — rename; same checks; writes UPDATE audit.
  - `DELETE /api/v1/countries/{id}` — **guarded**: 409 if any employee references
    it (`employees.country_id`); writes DELETE audit.
- `staff_frontend/lib/services/staff_service.dart` — `createCountry`,
  `updateCountry`, `deleteCountry` (`countries()` already existed).
- `staff_frontend/lib/screens/countries_list_screen.dart` — **new**; near-copy of
  `brands_list_screen.dart` (list, add/edit dialogs, multi-select delete,
  role-gated), Countries icon, no bulk button.
- `staff_frontend/lib/screens/brands_stores_hub_screen.dart` — new **Countries**
  hub tile under Positions.

## Diff summary
Additive only. Backend: 2 schemas + 3 endpoints. Frontend: 3 service methods +
1 new screen + 1 hub tile. No changes to the staff form, no DB migration.

## Deployment
- Built: no. Backend hot-reloaded the route change (dev `--reload`); a redeploy
  will carry it too. **Frontend not built** — run `flutter build web` (single
  origin) and deploy; then the Countries tile + form dropdown reflect new
  countries. Cloudflare `no-store` (changelog 0041) means no purge needed.

## Operator notes
- Manage countries: **Brands & Stores → Countries** (Admin / Super Admin).
- New countries appear in the staff-form Country dropdown immediately (already
  wired). To make Country **required**, enable it in **Form Settings → Employee**.
- A deleted country's id leaves a harmless sequence gap; not data.

## Rollback
- Revert the four edits and delete `countries_list_screen.dart`. No data or
  schema to undo (countries table pre-existed; guarded delete never orphans
  employees).
