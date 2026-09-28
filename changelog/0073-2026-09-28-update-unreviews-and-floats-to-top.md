# Changelog 0073 — Updating a row un-reviews it and floats it to the top

- **Timestamp:** 2026-09-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** When an employee row is updated (edit / promote-demote / additional
  store added), mark it **unreviewed** and move it to the **top** of the list.
- **Status:** Applied (backend + frontend). Verified via API and in-browser.

## What changed
### Backend
- **Model / migration:** new `employees.updated_at` (nullable TIMESTAMP, added via
  `ADD COLUMN IF NOT EXISTS`) — last data-change time. New helper
  `touch_for_review(emp)` sets `reviewed=False`, `reviewed_at=None`, and
  `updated_at=now`.
- Triggers call `touch_for_review`:
  - **`update_employee`** (PUT /{id}) — the full edit form **and** quick-edit
    save (covers "adding missing info" and additional-store changes via the
    form).
  - **`change_status`** — **promote and demote** (previously only promotion
    un-reviewed; promotion still also gets the blue "promotion — review" flag).
  - **`assign_store`** (cluster) — an Area Manager adding an **additional store**.
- **Schema:** `EmployeeRead.updated_at`, populated in both build sites.
- Marking a row **reviewed** does *not* set `updated_at`, so reviewing takes it
  back out of the top queue (as before).

### Frontend
- **`models/employee.dart`:** parse `updated_at`.
- **`screens/employees_list_screen.dart`:** the list now floats **recently
  changed, still-unreviewed** rows (`updated_at != null && !reviewed`) to the top,
  most-recent first; everything else keeps its order. This replaces the old
  IT-only promotion float (promotions now float for everyone via `updated_at`),
  so the unused `isIT` plumbing was removed. New hires (no `updated_at`) stay in
  their normal position — only *updates* float.

## Verification
- `python -m compileall` + `flutter analyze` — clean (only the 2 pre-existing
  `use_build_context_synchronously` infos); `flutter build web` — ok; backend
  hot-reloaded and created the column.
- **API (test record "Arif Test", restored after):** an edit set
  `reviewed=false` + `updated_at`; a **promote** set `reviewed=false`,
  `promotion_pending_review=true`, `updated_at`.
- **In-browser:** after editing "Arif Test", it jumped to the **very top** of the
  list as unreviewed (above rows without an `updated_at`); then restored.

## Notes
- Any save through the edit form un-reviews the row (even a no-op save) — that's
  the intent: touching a row sends it back for re-verification.
- **Move** (change primary store) is left as-is (not in the requested list); it
  can be added the same way if wanted.

## Rollback
- Revert the model/schema/route edits and the two frontend edits; delete this
  changelog. The `updated_at` column can be left (unused) or dropped.
