# Changelog 0072 — Review flags auto-clear when the flagged cell changes

- **Timestamp:** 2026-09-25 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** When a cell flagged for review (0071) has its value changed, clear
  that field's flag automatically.
- **Status:** Applied (backend only). Verified via API. Builds on 0071.

## What changed
`backend/app/api/routes/employees.py`:

- **`update_employee` (PUT /{id}) — the full-form and quick-edit save path:**
  before writing the new values, compare each flagged field's old vs new cell
  value and **keep a flag only while its value is unchanged**. So editing a
  flagged cell drops just that field from `review_fields`; untouched flags stay.
  - Comparison is by the value that drives the cell: name, payroll_id, dob,
    email, phone, payrate, mag_code, country_id, primary_store_id, position_id,
    and the **effective brand** (`_resolve_brand_id`, so a brand change via
    brand_id *or* store clears a "brand" flag). Strings are trimmed and ""/None
    treated alike.
- **`set_mag` (PATCH /{id}/mag-code):** changing the MAG card clears a `mag_code`
  flag.

No frontend change: each edit path already refreshes from the API response
(MAG uses the returned employee; the full form and quick edit call `_load()`),
so the purple highlight drops as soon as the cell is fixed.

## Verification (API, on Sandy Castillo; state restored after)
- Flagged email + phone + payrate → **edit only the phone** → flags became
  `[email, payrate]` (only phone cleared).
- **Change payrate 0 → 15** → `[email]` (payrate cleared).
- **No-op save** (email unchanged) → `[email]` kept.
- Flagged mag_code + email → **change MAG via /mag-code** → `[email]` (mag_code
  cleared).
- Employee fully restored (payrate 0, original phone/MAG, no flags, unreviewed).

## Notes
- Clearing a flag does not mark the row reviewed — it just removes that cell's
  highlight; the row still needs a final "reviewed" mark (or stays flagged by any
  remaining fields).
- A `position` flag is **not** auto-cleared by a promote/demote status change
  (that's a separate workflow with its own pending-review flag); it clears via a
  normal edit or on review. Out of scope here.

## Rollback
- Revert the two edits in `employees.py`; delete this changelog.
