# Changelog 0053 — Fix 500 saving an Area Manager (+ 2 sibling spots) & password reveal toggle

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** (1) Saving/updating an Area Manager (e.g. changing sherrel's password)
  returned **"Request failed (500)"**. (2) Add an **eye icon** to reveal the
  password on the user create/edit form so it can be confirmed.
- **Status:** Fixed & verified. Backend: re-saving sherrel (Area Manager, Pizza
  Boys) now 200; password change + login with the new password verified on a
  throwaway user. `compileall` clean; `flutter analyze` clean (one pre-existing
  lint elsewhere); built + deployed.

## The 500 (root cause + the rest of the family)
Same delete-then-re-add-in-one-flush bug as changelog 0048 (user_roles) and 0052
(store_brands / position_optouts). `_set_brands` replaced an AM's brands by
deleting all `area_manager_brands` rows and re-adding them in **one flush**;
SQLAlchemy emits same-table INSERTs before DELETEs, so keeping a covered brand
(Pizza Boys) re-inserted `(manager, brand)` while the old row still existed →
`uq_amb_manager_brand` violation → 500 on *any* save of that AM.

Swept the codebase for the pattern and fixed the **three** remaining spots with a
`session.flush()` between the delete and insert loops:
- `api/routes/users.py` — `_set_brands` (Area Manager brands, the reported one).
- `api/routes/users.py` — Store/Foodmall account store-link replace
  (`uq_storeusers_user`; would 500 when re-saving a Store/Foodmall user).
- `api/routes/employees.py` — employee additional-store replace
  (`uq_eas_employee_store`; would 500 editing an employee with a retained
  additional store).

All four helpers with this pattern (user_roles, store_brands, position_optouts,
area_manager_brands) plus the two set-replacements are now flush-guarded.

## Password reveal toggle (`users_screen.dart`)
Both **Reset/Password** and **Confirm password** fields get an eye
(`visibility`) `IconButton`; a single shared toggle reveals/hides both so the
value can be confirmed before saving. Uses the non-outlined `Icons.visibility` /
`Icons.visibility_off` glyphs (same as the login screen) — the `_outlined`
variants were dropped by the Flutter icon tree-shaker and rendered invisible.

## Rollback
- Remove the added `session.flush()` lines (reintroduces the 500s) and revert the
  users_screen eye-icon edit.
