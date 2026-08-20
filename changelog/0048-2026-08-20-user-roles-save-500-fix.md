# Changelog 0048 — Fix 500 when saving a user with an unchanged additional role

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Editing a user in **Users & Roles** and saving failed with
  **"Request failed (500)"** whenever an already-granted additional role (e.g.
  IT) was left checked.
- **Status:** Fixed and verified live against the running API (re-save unchanged,
  add, and remove additional roles all return 200). `python -m compileall` clean.
  Backend-only; hot-reloaded, no restart needed.

## Root cause
`_set_additional_roles` (`api/routes/users.py`) replaced a user's additional
roles by deleting all existing `user_roles` rows and re-adding the wanted ones in
**a single flush**. SQLAlchemy's unit-of-work orders same-table INSERTs *before*
DELETEs (no row-level dependency between them), so re-saving a role the user
already had inserted `(user_id, role)` while the old row still existed —
violating `uq_user_roles_user_role` and surfacing as a 500. This was a
pre-existing bug, triggered any time an unchanged additional role was saved.

## Fix
Added a `session.flush()` between the delete loop and the insert loop so the
DELETEs hit the database before the INSERTs. One line, no schema change.

```
for existing in ...: session.delete(existing)
session.flush()            # emit DELETEs before INSERTs
for r in clean: session.add(UserRoles(...))
session.commit()
```

## Verification
Against user `karisma` (primary HR, additional `[IT]`):
- Re-save `additional_roles=["IT"]` (the failing case) → **200**.
- Add `["IT","Admin"]` → 200; idempotent re-save → 200; remove back to `["IT"]`
  → 200. User restored to its original state.

## Rollback
- Remove the `session.flush()` line (reintroduces the bug).
