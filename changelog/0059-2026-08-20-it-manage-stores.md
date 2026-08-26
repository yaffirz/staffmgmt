# Changelog 0059 — Let IT add/manage stores

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Give the IT role the ability to add stores (org structure was
  Super Admin / Admin only).
- **Status:** Applied and verified via API (IT can create/edit/delete stores;
  brands & positions stay 403 for IT). `compileall` + `flutter analyze` clean;
  built + deployed.

## Backend (`api/routes/lookups.py`)
- New `STORE_MANAGE_ROLES = ("Super Admin", "Admin", "IT")`.
- `create_store`, `update_store`, `delete_store` now use it (were `ORG_ROLES`).
- **Brands, positions and countries are unchanged** — still `ORG_ROLES`
  (Super Admin / Admin only). Store *reads* were already open to any signed-in
  user, so IT's brand picker in the add-store dialog works.

## Frontend
- `dashboard_screen.dart` — IT now gets a **Brands & Stores** tile
  ("Add & manage stores").
- `org_child_list_screen.dart` — `_canEdit` includes IT **only on the Stores
  screen** (`_isStore`), via effective-role check (`hasRole('IT')`, so it also
  covers users who hold IT as an additional role). Positions stay read-only for
  IT; the Brands and Countries screens keep their own Admin-only edit gating.

## Scope note
IT gets full store management (add / edit / delete) because the Stores screen
couples those actions; brand/position/country management is untouched.

## Rollback
- Revert the four edits.
