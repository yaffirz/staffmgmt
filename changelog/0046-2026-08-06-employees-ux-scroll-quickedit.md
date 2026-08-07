# Changelog 0046 — Employees UX: visible scrollbars + quick-edit profile popup

- **Timestamp:** 2026-08-06 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** (A) Make the interface friendlier on tablets / other aspect ratios —
  the wide employee table overflowed with no visible way to scroll sideways.
  (B) Add a button in the Actions column to open a staffer's profile in a popup
  for quick edits.
- **Status:** Applied (frontend only). `flutter analyze` clean (new dialog:
  "No issues"; the two pre-existing infos in the list screen are unchanged).
  Built + deployed via `flutter build web`.

## A — App-wide visible scrollbars
- `staff_frontend/lib/main.dart`: a new `AppScrollBehavior` set on `MaterialApp`
  (`scrollBehavior:`). It (1) keeps scrollbars **always visible**
  (`thumbVisibility: true`) so horizontal scrolling on wide tables is
  discoverable, and (2) enables drag-scrolling with **any pointer**
  (mouse/trackpad/touch/stylus), which Flutter web otherwise limits to touch.
  This fixes the "side-scroll button doesn't appear" issue across the app,
  including the All-employees table.

## B — Quick-edit profile popup
- `staff_frontend/lib/screens/employee_quick_edit_dialog.dart` (**new**):
  `showEmployeeQuickEdit(context, employee)` opens a compact dialog pre-filled
  with the employee's details — name, payroll, DOB (date picker), brand → store →
  position (dependent, universal-role aware via `availableForBrand`), email,
  phone, pay rate + currency, country, MAG. Saves through the existing
  `PUT /employees/{id}` (preserving the employee's additional stores). Store /
  position dropdowns always include the current value to avoid the "value not in
  items" assertion for edge data.
- `staff_frontend/lib/screens/employees_list_screen.dart`: a new **Edit profile**
  action (badge icon) opens the popup and refreshes on save. The existing
  full-form editor is kept as **"Edit (full form)"**; Notes and Delete unchanged.

## Deployment
- Built: `flutter build web` (live via the tunnel bind mount; no Cloudflare purge
  — `no-store`, changelog 0041). Backend unchanged.

## Rollback
- Remove the `scrollBehavior:`/`AppScrollBehavior` from `main.dart`; drop the new
  dialog + its Actions button and the `onQuickEdit` wiring.
