# 0088 — Area Manager dashboard + external-platform access

**Date:** 2026-11-02

## What

A new **Area Dashboard** that lets Area Managers (and the back-office roles) see
their stores at a glance — the staff assigned to each store, each staffer's
position, and **which external/3rd-party platforms** (e.g. Taqtics, Oracle) each
staffer has access to, shown as a coloured tag next to their name.

## Why

Area Managers needed one screen to review their cluster's structure and track who
is provisioned on the company's external software, separate from the full
employee record. Access is modelled per-employee as a simple **has-access + an
optional note** (username / access level), displayed as a compact colour tag.

## Backend

- **Models** (`models/models.py`, new tables, non-destructive `create_all`):
  - `external_platforms` — the platform catalogue (`platform_id`, `tenant_id`,
    `name`, optional `color` hex, `created_at`; unique `tenant_id`+`name`).
  - `employee_platforms` — join of staffer ↔ platform with an optional `note`
    (`employee_id`, `platform_id`, `note`, `created_by`, `created_at`; unique
    `employee_id`+`platform_id`).
- **`routes/platforms.py`** (new, prefix `/api/v1`):
  - `GET /area-dashboard?brand_id=` — returns the visible brands, the selected
    brand's stores, each store's **active** staff (name, payroll id, position,
    platform tags), the platform catalogue, and `can_edit`.
  - `GET/POST /platforms`, `PATCH/DELETE /platforms/{id}` — manage the catalogue.
  - `PUT /employees/{employee_id}/platforms` — replace a staffer's platform set
    (delete→**flush**→insert, per the CLAUDE.md "replace child rows" rule to
    avoid the unique-constraint ordering 500).
  - Roles `MANAGE_ROLES = Super Admin, Admin, IT, HR, Area Manager`. Area
    Managers are **scoped to their own brand cluster** (`_am_brands`), both for
    which brands/stores they see and which staff they may edit
    (`_assert_can_edit_employee`); the back-office roles see all brands.
- Registered in `main.py`.

## Frontend

- **`models/platform.dart`** — `Platform`, `EmpPlatform` (platform + note),
  `DashStaff`, `DashStore`, `DashBrand`, `AreaDashboard` (+ `totalStaff`).
- **`services/staff_service.dart`** — `areaDashboard({brandId})`, `platforms()`,
  `createPlatform`, `deletePlatform`, `setEmployeePlatforms`.
- **`screens/area_dashboard_screen.dart`** (new) — brand dropdown, stat chips
  (stores / staff / platforms), a staff filter, and store sections listing each
  staffer with their position and coloured platform chips. An edit pencil opens
  **Platform access — <name>** (checkbox per catalogue platform + a note field
  each); a **Manage platforms** catalogue dialog adds/removes platforms with a
  6-colour palette. Edit controls appear only when `can_edit`.
- **Dashboard tile** "Area Dashboard" for Super Admin / Admin / IT / HR / Area
  Manager (`dashboard_screen.dart`).

## Verified

- `python -m compileall` on the new route + models (clean).
- `flutter analyze` on the changed Dart (no issues).
- In-browser as Super Admin: tile opens; brand picker switches cluster (St Kitts
  → Fresh To Go); stat chips update (1 store / 7 staff / 2 platforms); staff rows
  show positions; platform chips render (Oracle, Taqtics); the assign dialog
  loads existing access + notes and saves.

## Notes

No admin toggle added — the dashboard is a role-gated view, not a toggleable
feature; it surfaces only for the roles that may use it. Schema change is
additive (two new tables); no data touched.
