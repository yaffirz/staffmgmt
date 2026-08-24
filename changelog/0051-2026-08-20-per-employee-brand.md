# Changelog 0051 — Per-employee brand (foodmall staff reflect their own brand)

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Employees come in **per brand**. At a foodmall store (which carries
  several brands) every staffer was shown under the store's **primary** brand.
  Record and display the brand each staffer was actually hired under.
- **Status:** Applied. Backend verified end-to-end against the running API
  (foodmall hire under a carried brand reflects that brand; a brand the store
  doesn't carry → 400; omitting the brand falls back to the store's primary
  brand). `compileall` clean; `flutter analyze` clean; built + deployed.

## Model
- **`employees.brand_id`** (nullable FK → brands, non-destructive migration).
  When set it is the staffer's brand; when **NULL** (all existing rows) it falls
  back to the primary store's brand — so nothing changes for existing data until
  a record is next saved. A non-foodmall store serves one brand, so this simply
  equals the store's brand there.

## Backend (`api/routes/employees.py`, `notes.py`)
- `_store_brand_ids(store)` — brands a store serves (primary + foodmall extras).
- `_resolve_brand_id(payload, store)` — validates the chosen brand is one the
  store serves (else **400**) and defaults to the store's primary brand.
- `_effective_brand_id(emp, store)` — the brand to display (own, else store's).
- `create_employee` / `update_employee` validate and persist `brand_id`; the
  bulk import sets it from the row's resolved brand.
- `_enrich`, `list_employees`, and the individual staff page now resolve the
  displayed brand via the effective brand.
- `EmployeeCreate.brand_id` (input, optional) and `EmployeeRead.brand_id`
  (resolved output) added.

## Frontend
- `models/employee.dart` — `brandId`.
- `new_hire_wizard_screen.dart` — submits `brand_id` (the selected brand); on
  edit, prefills the brand from the staffer's own `brandId` (else the store's).
- `employee_quick_edit_dialog.dart` — same: prefills from `brandId`, submits it.

The employee-list Brand column/filter already keyed off the resolved `brand_name`,
so they now reflect the per-employee brand with no further change.

## Notes / scope
- Area-Manager scoping is unchanged (still store-based). This only changes the
  brand a staffer is *shown* under.
- Existing foodmall employees keep showing the store's primary brand until they
  are next edited (then the chosen brand is saved). They can be re-pointed via
  the edit form or quick-edit.

## Rollback
- Revert the edits. The `brand_id` column is additive and harmless if unused.
