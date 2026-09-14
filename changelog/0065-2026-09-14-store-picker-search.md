# Changelog 0065 — Searchable store picker in the new-hire / edit-employee wizard

- **Timestamp:** 2026-09-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** The **Primary store** picker on the Add/Edit employee form
  (Role & store step) opened a plain full-screen dropdown — unwieldy once a brand
  has many stores. Add a **search bar** so a store is easy to find.
- **Status:** Applied (frontend only; no schema/API change). Verified in-browser.

## What changed
`staff_frontend/lib/screens/new_hire_wizard_screen.dart` (the shared new-hire /
**Edit employee** wizard):

- **Primary store** — replaced the `DropdownButtonFormField<int>` with a new
  **`_StoreSearchField`** (a `FormField<int>` rendered via `InputDecorator` with a
  search-icon suffix). Tapping it opens **`_StoreSearchDialog`**: an autofocused
  "Search stores" box over a filtered `ListView` (case-insensitive substring on
  the store name), with a check on the current selection; picking a row fills the
  field. Keeps the existing validation ("Primary store is required"), the
  brand-reset key (`ValueKey('store-$_brandId-$_resetTick')`), the
  "Choose a brand first" helper, and the disabled-until-a-brand behaviour.
- **Additional stores** — the multi-select "Add additional stores" dialog gained
  the same **search box** above its checkbox list (fixed-height, scrollable),
  with a "No stores match." empty state. Same add-on-OK behaviour as before.

Both pickers filter the already-brand-scoped store list (`_storesForBrand`), so
search only ever offers stores valid for the chosen brand.

## Verification
- `flutter analyze` — no new issues (only a pre-existing-style `withOpacity`
  deprecation info, consistent with the rest of the codebase).
- `flutter build web` — succeeds.
- **In-browser (localhost:8000):** on the New hire → Role & store step, the
  Primary store field shows a search icon and is disabled until a brand is
  chosen; with brand "Pizza Boys" selected, tapping it opened the Select-store
  dialog, typing "chag" filtered to **Chaguanas**, and picking it populated the
  field. The Add-additional-stores dialog's new search box filtered to **Arima**.
  No test employee was created (wizard cancelled).

## Rollback
- Revert the edits to `new_hire_wizard_screen.dart`; delete this changelog file.
