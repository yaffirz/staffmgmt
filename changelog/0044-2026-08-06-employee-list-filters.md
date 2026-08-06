# Changelog 0044 — Filter the employee list by brand / store / position / country

- **Timestamp:** 2026-08-06 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add a filter to the **All employees** list so you can narrow it by a
  particular brand, store, position, or country (beside the existing search).
- **Status:** Applied (frontend only). `flutter analyze` clean — no new issues
  (the file's two pre-existing `use_build_context_synchronously` infos in the
  unrelated edit/delete handlers are unchanged). **Not built/deployed** —
  frontend needs `flutter build web` + a deploy.

## What changed
The list already loads all employees client-side and filters them by a search
string. This extends that same client-side filter with four facets — **Brand,
Store, Position, Country** — combined with the search box as **AND**. No backend
or data-model change.

- A **Filter** icon (with an active-count badge) sits in the table header's
  action area (right of the search box) and opens a dialog with four
  **"All"-defaulted** dropdowns. Dropdown options are derived from the values
  actually present in the loaded employees (so only meaningful choices appear),
  sorted alphabetically.
- Applied filters show as **removable chips** above the table, plus a
  **Clear all** button. The dialog also has its own **Clear** action.

## Files touched
- `staff_frontend/lib/screens/employees_list_screen.dart`:
  - State: `_fBrand/_fStore/_fPosition/_fCountry` (null = All), an
    `_activeFilterCount` getter, and a `_distinct(...)` option-builder.
  - `_openFilters()` dialog, `_applyFilters()`, and `_activeFiltersBar()`.
  - Header gains a badged **Filter** button via `PaginatedDataTable.actions`;
    the body is wrapped so the active-filter chips render above the table.
  - `_EmployeeDataSource`: facet fields + `setFilters(...)`; `_applyFilter()`
    now applies the four facets then the search query.

## Deployment
- Built: no. Frontend-only — run `flutter build web` + deploy. Cloudflare
  `no-store` (changelog 0041) means no purge needed.

## Rollback
- Revert the single-file edit to `employees_list_screen.dart`.
