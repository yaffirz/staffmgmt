# Changelog 0064 — Promotions flag the row for IT review (blue + float to top)

- **Timestamp:** 2026-09-08 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** When a staffer is promoted, mark them **unreviewed** and highlight the
  row **blue** in the employee list, and **float that row to the top** when an
  **IT** user is viewing, so IT can review and update them.
- **Status:** Applied (backend + frontend). Verified end-to-end in-browser.

## What changed
A new `employees.promotion_pending_review` flag drives a blue "needs review"
state that IT sees first.

### Backend
- **`models.py` + `database.py`:** new column
  `promotion_pending_review BOOLEAN NOT NULL DEFAULT false` (non-destructive
  `ADD COLUMN IF NOT EXISTS`).
- **`schemas/employee.py` + `routes/employees.py`:** `EmployeeRead` now carries
  `promotion_pending_review` (populated in both the single-employee `_enrich`
  and the list builder).
- **`routes/status.py` — on `PROMOTION`:** after changing the position, set
  `reviewed = False`, `reviewed_at = None`, `promotion_pending_review = True`.
  (Demotion/terminate/reactivate are unchanged.)
- **`routes/employees.py` — `set_reviewed`:** marking a row **reviewed** now also
  clears `promotion_pending_review` (the review has happened). Un-reviewing does
  not re-raise it.

### Frontend
- **`models/employee.dart`:** parse `promotion_pending_review`.
- **`screens/employees_list_screen.dart`:**
  - **Blue row tint** (`0x332196F3`) for a promotion-pending row. Precedence:
    amber "email pending" → **blue "promotion, review me"** → green "reviewed".
  - **Float to top for IT:** the data source takes an `isIT` flag
    (`user.hasRole('IT')`); when set, promotion-pending rows are stably moved to
    the top of the filtered list. Non-IT viewers keep the normal order.
  - The review toggle's tooltip reads "Promoted — review, then mark reviewed"
    while the flag is set. Marking reviewed clears the blue and (for IT) drops it
    out of the top group.

## Bug fixed along the way (was blocking every promotion to a universal role)
`routes/status.py`'s promote/demote brand check rejected **universal positions**
(`positions.brand_id IS NULL`): `pos.brand_id != emp_brand_id` is always true when
`pos.brand_id` is NULL, so `"That position belongs to a different brand"` fired for
all 20 of the 22 seeded positions. The check now mirrors the frontend
`Position.availableForBrand`: a position is valid if it is brand-specific and
matches the staffer's brand, **or** universal and not opted out for that brand
(`position_brand_optouts`). It also now prefers the employee's own `brand_id`
(falling back to the primary store's brand), matching the position picker.

## Verification
- `python -m compileall` on all changed backend files — clean.
- `flutter analyze` on the changed Dart — no new issues (only pre-existing
  `use_build_context_synchronously` infos).
- `flutter build web` — succeeds.
- **In-browser (localhost:8000):** promoted test staffer "1234" (Cashier →
  Assistant Manager, a universal position — succeeded after the brand fix). DB
  confirmed `reviewed=f, reviewed_at=NULL, promotion_pending_review=t`. Employee
  list showed the row **blue + unreviewed**. Signed in with the **IT** role: the
  row **floated to the top**. Marked it **reviewed**: DB became
  `reviewed=t, reviewed_at set, promotion_pending_review=f`, the row left the top
  group and turned green. (A temporary IT role granted to superadmin for the IT
  test was removed afterward; test record "1234" is left promoted/reviewed.)

## Rollback
- Revert the five backend files and two frontend files; delete this changelog.
- The `promotion_pending_review` column can stay (unused) or be dropped with
  `ALTER TABLE employees DROP COLUMN promotion_pending_review;`.
