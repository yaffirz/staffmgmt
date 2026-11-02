# 0089 — Ops Manager role + store-level clusters + Clusters admin screen

**Date:** 2026-11-02

## What

Adds the **Operations Manager (Ops Manager)** tier above Area Manager, moves
Area Manager clusters to **store-level**, and gives Admin / IT / HR a dedicated
**Clusters** screen to assign them.

Management hierarchy:

    Ops Manager (brands)  >  Area Manager (stores)  >  store mgrs/supervisors  >  staff

- An **Ops Manager** owns whole **brand(s)** and sees everything an Area Manager
  sees, but across all stores in those brands (i.e. all the AM clusters within
  them).
- An **Area Manager** owns a cluster of **specific stores**. Usually those
  stores all belong to one brand (even a foodmall — only that brand), but the
  set is free-form so an AM can span brands for the exceptions.
- **New staff auto-populate**: the dashboards query active staff live by store,
  so a new hire at a cluster store shows up immediately for that AM/Ops Manager.
- **Only Admin / IT / HR** can set clusters (new Clusters screen).

## Why

Area Managers needed finer, per-store clusters set centrally, and the business
has an Ops tier above them that owns a whole brand. Previously AM scope was
brand-only and could only be set (as brands) inside the per-user dialog by
Super Admin / Admin.

## Backend

- **New role** `Ops Manager` — added to `ALLOWED_ROLES` and the `users.role`
  CHECK (widened via the idempotent drop/recreate migration in `database.py`).
- **New table** `ops_manager_brands` (`user_id`, `brand_id`; unique pair) — the
  brands an Ops Manager owns. Keyed directly on the user (no manager-row
  indirection). `area_manager_stores` (previously unused) now holds AM clusters.
- **`core/scoping.py`** (new, shared) — `dashboard_scope(session, current)`
  returns the `(brand_ids, store_ids)` a caller may see (`None` = unrestricted
  for Super Admin / Admin / IT / HR). AM store set = explicit
  `area_manager_stores`, **falling back** to "all stores in the legacy
  `area_manager_brands`" when none are set (so pre-existing AMs keep working
  until assigned a store cluster). Also `effective_brand_id` (employee brand
  else store brand) for multi-brand foodmalls.
- **`routes/platforms.py`** — the Area Dashboard now uses `dashboard_scope`:
  Ops Managers see their brands' stores, AMs only their cluster stores within a
  brand, and in a multi-brand foodmall staff are filtered to the selected
  brand. `MANAGE_ROLES` gains `Ops Manager`. Edit-permission check uses the
  scope's store set.
- **`routes/cluster.py`** — `_am_scope` now resolves the AM's stores through the
  same shared helper, so **My Cluster** and the Move/Request/Assign flows are
  store-level and coherent with the dashboard.
- **`routes/clusters.py`** (new, Admin/IT/HR) —
  `GET /api/v1/clusters/overview`, `PUT /clusters/area-manager/{user_id}/stores`,
  `PUT /clusters/ops-manager/{user_id}/brands`. Writes use delete→flush→insert
  (the child-rows ordering rule) and are audited.

## Frontend

- **`screens/clusters_screen.dart`** (new) — two tabs. *Area Managers*: each AM
  with a store summary (`N stores · brands`) and an **Edit** store picker
  (grouped by brand, per-brand "All", live filter). *Ops Managers*: each with a
  brand picker. Saves via the new service calls.
- **`models/cluster_admin.dart`** + `StaffService.clustersOverview` /
  `setAreaManagerStores` / `setOpsManagerBrands`.
- **Dashboard tiles** (`dashboard_screen.dart`): **Clusters** tile for
  Super Admin / Admin / IT / HR; **Area Dashboard** tile now also shown to
  Ops Manager.
- `Ops Manager` added to the Users & Roles role dropdown.

## Verified

- `python -m compileall` (backend) + `flutter analyze` / `flutter build web`
  (frontend) clean.
- Restarted backend: `ops_manager_brands` created, role CHECK now includes
  `Ops Manager` (non-destructive).
- Set **Sherrel Walters** (AM, user 20) a store cluster of Arima + Chaguanas +
  Cunupia → her `dashboard_scope` resolves to exactly those 3 stores (brand
  Pizza Boys); her Area Dashboard shows only those stores and cannot escape to
  another brand. Admin scope stays unrestricted.
- Created a temp Ops Manager over Pizza Boys + Fresh To Go → sees both brands'
  stores (27) and the full Fresh To Go store (7 staff); temp account removed
  after verifying. Clusters screen tested in-browser (both tabs, store picker,
  Ops brand summary).

## Notes

- No admin toggle — this is role-gated structure, not a toggleable feature.
- Backward compatible: AMs with only legacy brand links keep their old
  (brand-wide) cluster until an admin assigns stores. **Sherrel's cluster was
  left set to the 3 demo stores** — reset it to all of Pizza Boys (or any set)
  from the Clusters screen if that was just for the demo.
- The Clusters screen lists managers by effective role (primary or additional).
