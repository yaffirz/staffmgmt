# 0092 — Area Dashboard: "View as area manager" filter (admins)

**Date:** 2026-11-02

## What

The Area Dashboard gains a **View as area manager** picker (admin roles only).
An admin can select any Area Manager and see the dashboard exactly as that AM
sees it — scoped to the AM's store cluster and brands — without logging in as
them.

## Why

Admins (Super Admin / Admin / IT / HR) needed to review each Area Manager's
cluster from one place, and to verify/test an AM's view (e.g. Sherrel Walters)
without creating or resetting that AM's credentials.

## Changes

- **`routes/platforms.py`** — `GET /area-dashboard` now accepts an optional
  `area_manager_id`. For an admin caller it returns `area_managers` (every
  account whose effective role is Area Manager) and, when `area_manager_id` is
  given, narrows the whole dashboard to that AM's cluster
  (`am_cluster_store_ids` → `brands_of_stores`). Non-admin callers (AM/Ops
  Managers) get an empty `area_managers` list and are unaffected — they only
  ever see their own scope. New `AmLite` schema + `area_manager_id` echo on the
  response.
- **Frontend** — `area_dashboard_screen.dart` adds the "View as area manager"
  dropdown (shown only when `areaManagers` is non-empty, i.e. admins). Selecting
  an AM re-fetches scoped to them (and resets the brand to the AM's default).
  The controls now always render for admins so they can switch back even when a
  chosen AM has an empty cluster. `platform.dart` gains `DashAreaManager` +
  `AreaDashboard.areaManagers/areaManagerId`; `StaffService.areaDashboard` takes
  `areaManagerId`.

## Verified

- `python -m compileall` + `flutter analyze` / `flutter build web` clean.
- API: admin dashboard lists the 4 AMs; `?area_manager_id=20` (Sherrel) scopes
  to her cluster (Arima, Chaguanas, Cunupia, St Anns; brands Pizza Boys +
  Rituals).
- In-browser: selecting **sherrel** in "View as area manager" shows her 4-store,
  6-staff cluster exactly as she'd see it.

## Note

This answers "do I need separate credentials to test Sherrel?" — **no**. An
admin can view her dashboard via this picker. She only needs her own password if
*she* is to log in (set it from Users & Roles — reset link or force-change).
