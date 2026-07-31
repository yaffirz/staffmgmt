# Changelog 0036 — Store & Foodmall roles (branded, restricted staff view)

- **Timestamp:** 2026-07-30 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Store-level logins that see only their own store's staff, restricted
  to name + brand (no position/pay/contact). A Foodmall is a store carrying
  multiple brands; its account sees staff grouped by brand. Both can request a
  staffer be added to their store.
- **Status:** Applied; backend verified end-to-end via API; `flutter analyze`
  clean.

## Data model (`models.py`, migrations in `database.py`)
- New roles `Store`, `Foodmall` (ALLOWED_ROLES + in-model CHECK + idempotent
  drop/recreate of `ck_users_role`).
- `Stores.is_foodmall` (bool, migrated with `ADD COLUMN IF NOT EXISTS`).
- New tables (create_all): `store_brands` (a foodmall store's extra brands beyond
  its primary `brand_id`); `store_users` (binds a Store/Foodmall account to one
  store, `unique(user_id)`).

## Foodmall stores (`routes/lookups.py`, `schemas/lookups.py`)
- Store create/update accept `is_foodmall` + `extra_brand_ids`; `store_brands`
  replaced accordingly (extras validated in-tenant, primary excluded). Store reads
  return `is_foodmall` + `extra_brand_ids`. Delete blocks if a Store/Foodmall
  account is bound; cleans up `store_brands`.
- Frontend `org_child_list_screen.dart`: store dialogs gain a **"This is a
  foodmall"** checkbox → additional-brand chips.

## Restricted portal (`routes/store_portal.py`, `schemas/store_portal.py`)
- `require_roles("Store","Foodmall")`; store resolved via `store_users` (403 if
  unlinked). `GET /store/summary` → staff grouped by brand, **name only** (a
  staffer's brand = their position's brand, fallback store primary).
  `GET /store/employees/search` (name only). `POST /store/request-staff` → Admin
  notification + audit, no staff change (mirrors `cluster.py` request).
- Store/Foodmall are **not** in any employee/cluster role list — full-detail
  endpoints stay closed (verified: 403 on `/employees`, `/cluster`, `/users`).

## Accounts (`routes/users.py`, `schemas/user.py`)
- `store_id` on create/update; `store_id`/`store_name` on read. `store_users` link
  upserted for Store/Foodmall, removed on role change/delete. **Store validated
  before the row is created** (no orphaned account on a bad store — fixed after a
  test caught it). Foodmall must point at a foodmall store (422 otherwise).

## Frontend
- `dashboard_screen.dart`: `Store` → "My Store", `Foodmall` → "My Foodmall" tile.
- New `my_store_screen.dart`: brand-grouped staff (name only) + a "Request staff"
  search dialog. `users_screen.dart`: role dropdown gains Store/Foodmall + a
  single-store picker (foodmall stores filtered for Foodmall); rows show the bound
  store. Models/service updated (`directory.dart`, `user_account.dart`,
  `store_summary.dart`, `staff_service.dart`).

## Verification (API)
- Foodmall store (Pizza Boys + Churchs + Rituals) created; Store + Foodmall
  accounts created; Foodmall→non-foodmall store rejected (422, no orphan). Store
  account `/store/summary` returned name+brand only and got 403 on the full
  endpoints; Foodmall grouped by its 3 brands; `request-staff` created an Admin
  notification.

## Deployment
- Built: web rebuilt. Live via tunnel. Prod: yes (single-origin).

## Rollback
- Revert edits; drop `store_portal.py`, `store_users`/`store_brands` tables, the
  `Store`/`Foodmall` roles, and `stores.is_foodmall`.
