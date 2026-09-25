# Changelog 0071 — Admin/IT can flag which cells need review

- **Timestamp:** 2026-09-25 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A button (IT and Admins only) to mark rows as **pending review** and
  **highlight which cell** requires the review.
- **Status:** Applied (backend + frontend). Verified via API and in-browser.

## What changed
A per-row **"Flag for review"** action lets Admin / Super Admin / IT pick the
exact cells that need a second look. Flagged cells are highlighted purple, the
row is tinted purple, and the row goes back to "pending review".

### Backend
- **Model / migration:** new `employees.review_fields` JSONB list (non-destructive
  `ADD COLUMN IF NOT EXISTS … '[]'::jsonb`). Non-empty = pending review.
- **`routes/employees.py`:** `PATCH /api/v1/employees/{id}/review-flag`
  `{fields:[...]}` — restricted to **Super Admin / Admin / IT**
  (`REVIEW_FLAG_ROLES`). Keeps only known keys (`REVIEWABLE_FIELDS`), de-duped and
  canonically ordered. A non-empty set clears `reviewed` (+ `reviewed_at`); an
  empty set clears the flag. Audited.
- **`set_reviewed`:** marking a row reviewed now also clears `review_fields`
  (like the promotion flag).
- **Schema:** `EmployeeRead.review_fields`; new `ReviewFlagUpdate` body; populated
  in both `EmployeeRead` build sites.

### Frontend
- **`models/employee.dart`:** parse `review_fields`.
- **`services/staff_service.dart`:** `setReviewFlag(id, fields)`.
- **`screens/employees_list_screen.dart`:**
  - A **flag** action button in each row's Actions (outlined when clear, filled
    purple when flagged), shown only to Admin / Super Admin / IT. It opens a
    **"Flag for review — {name}"** dialog: a checkbox per reviewable column
    (`kReviewableFields`, matching the backend), pre-filled from the current
    flags, with **Save** / **Clear flag** / Cancel.
  - Flagged cells get a **purple** highlight box; the row is tinted purple, at the
    top of the tint precedence (purple flag → amber no-email/0.00 → blue promotion
    → green reviewed).

## Verification
- `python -m compileall` + `flutter analyze` — clean (only the 2 pre-existing
  `use_build_context_synchronously` infos); `flutter build web` — ok; backend
  hot-reloaded and created the column.
- **API:** flag with an unknown key → dropped, canonical order, `reviewed=false`;
  empty set clears; an **Admin/IT** token is accepted, and role gating is via the
  standard `require_roles` (a pure-HR user would be rejected — `hr_test` passed
  only because it also holds IT).
- **In-browser (superadmin):** flagged Sandy Castillo (email/phone/pay rate) → row
  turned **purple** with those three cells purple-highlighted (pay rate showed
  both its amber 0.00 state and the purple box); the Actions flag icon was filled
  purple. Opening the dialog showed the three boxes pre-checked; **Clear flag**
  removed everything and the row reverted to amber. DB left clean (no flags).

## Notes
- No settings on/off toggle: this is a role-gated admin capability (like "IT can
  manage stores"), not a platform feature toggle.
- Field keys/labels/order are shared between backend `REVIEWABLE_FIELDS` and
  frontend `kReviewableFields` — keep them in sync if columns change.

## Rollback
- Revert the backend + three frontend edits; delete this changelog. The
  `review_fields` column can be left (unused) or dropped.
