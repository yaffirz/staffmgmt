# Changelog 0045 — Universal positions (job roles across all brands)

- **Timestamp:** 2026-08-06 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Let a job role be defined **once** and be available across **all
  brands**, with a per-brand switch to turn it **off** for specific brands —
  instead of re-creating the same position under every brand.
- **Status:** Applied. Backend verified end-to-end against the running API
  (create universal + opt-out, per-brand visibility, update, guarded delete +
  opt-out cleanup); migration confirmed applied (brand_id nullable +
  `position_brand_optouts` table); `compileall` clean; `flutter analyze` clean
  (no new issues). **Frontend not built/deployed** — needs `flutter build web`.

## Model
- **`positions.brand_id` is now nullable.** `NULL` = a **universal** role
  (available to every brand). Existing brand-specific positions are unchanged.
  Migration: `ALTER TABLE positions ALTER COLUMN brand_id DROP NOT NULL`
  (non-destructive, in `_MIGRATIONS`).
- New table **`position_brand_optouts`** `(position_id, brand_id)` — a row means
  a universal role is switched **off** for that brand. No row = available. Created
  by `create_all`.
- **Resolution:** a brand's positions = its own brand-specific rows **plus**
  universal rows not opted out for it. Employees still reference a single
  `position_id` (universal or brand-specific); create/update only validate the
  position's tenant, so universal roles are assignable with no other change.

## Files touched
- `backend/app/models/models.py` — `Positions.brand_id` Optional;
  `PositionBrandOptOuts` table.
- `backend/app/core/database.py` — the `DROP NOT NULL` migration.
- `backend/app/schemas/lookups.py` — `PositionRead` gains `universal` +
  `disabled_brand_ids`; `PositionCreate`/`PositionUpdate` accept `brand_id=null`
  + `disabled_brand_ids`.
- `backend/app/api/routes/lookups.py` — `_position_read` / `_set_position_optouts`
  helpers; create/update/list/delete handle universal roles + opt-outs;
  `GET /positions?brand_id=` now returns brand-specific + available universals.
- `backend/app/api/routes/employees.py` — bulk import resolves a universal role
  by title when no brand-specific match exists (respecting opt-outs).
- `staff_frontend/lib/models/directory.dart` — `Position.brandId` nullable +
  `universal`/`disabledBrandIds` + `availableForBrand()`.
- `staff_frontend/lib/services/staff_service.dart` — create/updatePosition accept
  nullable brand + `disabledBrandIds`.
- `staff_frontend/lib/screens/new_hire_wizard_screen.dart` — position dropdown
  uses `availableForBrand`.
- `staff_frontend/lib/screens/org_child_list_screen.dart` — Positions add/edit
  gains **"All brands (universal)"** + per-brand on/off switches; rows show a
  universal summary ("All brands" / "All brands except …"); brand filter includes
  available universals.
- `staff_frontend/lib/screens/employee_detail_screen.dart` — change-position
  picker includes universal roles available to the employee's brand.

## Not included
- **Bulk position CSV** stays brand-specific (`brand_name, position_title`);
  universal roles are created via the UI. (Can add a bulk path later if wanted.)

## Deployment
- Backend hot-reloaded (migration ran on reload). Frontend needs
  `flutter build web` + deploy (no Cloudflare purge — `no-store`, changelog 0041).

## Rollback
- Revert the edits. The nullable column + `position_brand_optouts` table are
  additive and harmless if unused; any universal positions would need reassigning
  before dropping them.
