# Changelog 0047 — Employee filters: fix blank dialog + add provenance/date/month filters

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** The **All employees → Filter** dialog rendered as a blank grey box
  (unusable). Fix it, add **preset** quick-filters, and add new facets: **who
  added** a staffer, the **date added**, the **date marked completed**, and an
  **option to filter by month**. Test before committing.
- **Status:** Applied and **verified live** in the browser against the running
  stack (backend curl-tested end-to-end; frontend driven in a real session —
  dialog renders, presets/dropdowns/chips/badge/date-picker all work, filter
  narrows the list correctly). `python -m compileall` clean; `flutter analyze`
  clean (only the file's two pre-existing `use_build_context_synchronously`
  infos in the MAG/edit handlers). Built + deployed via `flutter build web`.

## Root cause of the blank dialog (was broken since 0044)
`AlertDialog.actions` are laid out in an **`OverflowBar`**, not a `Row`/`Flex`.
The actions list contained a **`const Spacer()`** (an `Expanded`) to push
Clear left of Cancel/Apply. `Expanded`/`Spacer` only work inside a `Flex`, so
it threw *"Incorrect use of ParentDataWidget … Expanded … inside OverflowBar"*
during build. In a **release** web build Flutter swallows that into a grey
`ErrorWidget`, which is the blank box the user saw. The 0044 dialog had the same
`Spacer`, so it was already broken. **Fix:** removed the `Spacer`; the three
actions (Clear / Cancel / Apply) now sit together, right-aligned.

Also hardened the filter dropdowns: switched from `DropdownButtonFormField<String?>`
with a null-valued "All" item to `DropdownButtonFormField<String>` with a
sentinel value (matching the proven pattern in `employee_quick_edit_dialog.dart`).

## Backend — new provenance/completion fields
`employees` gains two nullable columns (historical rows stay NULL):
- **`created_by`** (INTEGER, FK users) — the signed-in user who added the record.
- **`reviewed_at`** (TIMESTAMP) — when the row was last marked reviewed.

Files:
- `models/models.py` — `Employees.created_by` + `Employees.reviewed_at`.
- `core/database.py` — two non-destructive migrations
  (`ADD COLUMN IF NOT EXISTS created_by INTEGER` / `reviewed_at TIMESTAMP`).
- `schemas/employee.py` — `EmployeeRead` gains `created_by`, `reviewed_at`, and
  the resolved `created_by_name` (username).
- `api/routes/employees.py`:
  - `create_employee` sets `created_by=current.user_id`; `bulk_employees` sets it
    on every imported row.
  - `set_reviewed` stamps `reviewed_at=utcnow()` when marked reviewed, clears it
    when un-reviewed.
  - `_enrich` + `list_employees` resolve and return `created_by` /
    `created_by_name` / `reviewed_at` (list preloads a `users` map — no per-row
    query).

## Frontend
- `models/employee.dart` — parse `created_at`, `created_by`, `created_by_name`,
  `reviewed_at`; add `createdAtDisplay` / `reviewedAtDisplay` (MM/DD/YYYY) and
  `addedMonthKey` ("YYYY-MM").
- `screens/employees_list_screen.dart`:
  - **Filter dialog rebuilt** (scrollable, width 420): a **Quick filters** row
    (Reviewed, Pending review, Added this month, Completed this month, and
    "Added by me" when the current user has added anyone) that stays in sync with
    the detailed controls below; **Review status**, Brand, Store, Position,
    Country, **Added by**, **Added in month** dropdowns; **Date added** and
    **Date completed** From/To pickers. Clear / Cancel / Apply.
  - Filtering (all AND-combined with the search box) added to
    `_EmployeeDataSource`: reviewed, added-by, added-month, and day-granular
    date-added / date-completed ranges (`_dateInRange`, "To" day inclusive).
  - Active-filter **chips** + count **badge** extended to every new facet;
    `Clear all` resets everything.
  - Three new table columns — **Added**, **Added by**, **Completed** — so the new
    facets are legible (the table already scrolls horizontally, changelog 0046).
  - `created_by_name` added to the free-text search haystack.

## Not toggled
Filtering is core list UI (always on), not a feature flag, so no admin toggle was
added (standing rule #2 applies to toggleable features).

## Deployment
- Backend hot-reloaded on edit (migrations ran on reload; columns confirmed in
  `information_schema`). Frontend built with `flutter build web` — served
  same-origin at `/` and via the Cloudflare tunnel (`no-store`, changelog 0041 —
  no purge needed). **Hard-refresh once** to drop any old in-memory bundle.
- Note: on Docker Desktop (Windows) the `staff_frontend/build/web` bind mount can
  lag a few seconds after a build; reload again if the first load shows old UI.

## Rollback
- Revert the frontend edits (drop the new columns/filters) and the backend edits.
  The `created_by` / `reviewed_at` columns are additive and harmless if unused.
