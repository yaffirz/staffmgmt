# Changelog 0014 — Store drilldown as a selectable table

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Turn the store drilldown's staff cards into a table with selectable
  (highlightable/copyable) text, keeping the tags.
- **Status:** Applied on disk; `flutter analyze` clean (no issues). Loads with the
  same pending frontend restart as 0012/0013.

## What changed
- `screens/store_drilldown_screen.dart`: replaced the per-staff `Container` cards
  with a `DataTable`:
  - Columns: **Name · Position · Payroll ID · Status**.
  - Every cell uses `SelectableText`, so text can be highlighted and copied
    (matching the All Employees table).
  - The **Status** column holds the tags: "Recently added" (the deep-linked
    employee) and/or "Also covers" (additional-store staff).
  - The highlighted employee's row keeps a `primaryContainer` background.
  - Table wrapped in a horizontal scroll view for narrow viewports; the header
    (store name, brand, staff count) and loading/error/empty states are unchanged.

## Files touched
- staff_frontend/lib/screens/store_drilldown_screen.dart — cards → DataTable

## Verification
- `flutter analyze` → No issues found.
- Pending: same frontend restart as 0013 (new files) to confirm in-browser.

## Deployment
- Built: no. Frontend restart required.
- Deployed to production: no

## Rollback
- Revert the store_drilldown_screen.dart edit (reverts to the card layout).
