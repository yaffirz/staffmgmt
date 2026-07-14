# Changelog 0017 — Staff page + notes UI, entry points, notes toggle

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Frontend for the individual staff page with notes (per-note visibility
  chosen by the author), entry points into it, and the staff-notes admin toggle.
- **Status:** Applied on disk; `flutter analyze` = 4 info lints, 0 errors/warnings.
  Pending a full frontend restart (new files). Backend already verified (0016).

## What changed
- **Models:** `models/staff_page.dart` (StaffPageEmployee), `models/staff_note.dart`
  (StaffNote with visibility fields + label + can_edit).
- **Service:** `staffPage(id)`, `staffNotes(id)`, `createNote(...)`,
  `deleteNote(id)`, `myBrands()`.
- **Individual staff page** (`screens/employee_detail_screen.dart`, new): header
  (name, payroll, position, store, brand — selectable) + notes list (text, author,
  date, a visibility chip: lock icon "Private" or "roles / Brand: X") + delete for
  own/Super Admin notes. **Add note** dialog: multiline text + audience choice
  (Private / Roles / Brands). Roles = HR/Admin/Area Manager chips; Brands = all
  brands, **defaulted to the author's own brand(s)** (from /me/brands). Handles the
  "notes disabled" 403 inline.
- **Entry points:** tap a staffer in My Cluster; tap a row in the store drilldown;
  a Notes action in the All Employees table.
- **Settings:** added a "Staff notes enabled" switch alongside the move toggle.

## Files touched
- staff_frontend/lib/models/staff_page.dart — NEW
- staff_frontend/lib/models/staff_note.dart — NEW
- staff_frontend/lib/screens/employee_detail_screen.dart — NEW
- staff_frontend/lib/services/staff_service.dart — staff page + notes + myBrands
- staff_frontend/lib/screens/my_cluster_screen.dart — staff row → staff page
- staff_frontend/lib/screens/store_drilldown_screen.dart — row → staff page
- staff_frontend/lib/screens/employees_list_screen.dart — Notes action
- staff_frontend/lib/screens/settings_screen.dart — staff_notes_enabled switch

## Verification
- `flutter analyze` → 0 errors/warnings; 4 info `use_build_context_synchronously`
  (2 pre-existing in employees_list; 2 new but mounted-guarded in helpers, matching
  the existing codebase pattern).
- Pending full frontend restart, then in-browser:
  - am_pizza: open a staffer from My Cluster; add Private / Role / Brand notes
    (brand picker defaults to Pizza Boys); delete own note.
  - hr_test: sees only the HR-shared note.
  - superadmin: Settings → Staff notes off → am_pizza add-note blocked inline.

## Deployment
- Built: no. Frontend full restart required (new files).
- Deployed to production: no

## Rollback
- Remove the new screen + two models, revert staff_service.dart and the four
  screen edits.
