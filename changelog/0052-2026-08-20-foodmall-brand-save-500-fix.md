# Changelog 0052 — Fix 500 when editing a foodmall's brands (retained-brand collision)

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif (surfaced while editing Trincity Foodcourt's brands)
- **Task:** Saving a foodmall store's carried brands returned **500** whenever an
  already-assigned extra brand was kept in the selection.
- **Status:** Fixed and verified (PATCH now 200; Trincity Foodcourt updated to
  carry Pizza Boys + Rituals Coffee House). `compileall` clean; backend
  hot-reloaded.

## Root cause
Same class of bug as changelog 0048 (`user_roles`). `_set_store_brands`
(`api/routes/lookups.py`) replaces a store's extra brands by deleting all
`store_brands` rows and re-adding the wanted ones **in one flush**. SQLAlchemy
emits same-table INSERTs before DELETEs, so re-adding a brand the store already
had inserted `(store_id, brand_id)` while the old row still existed — violating
`uq_storebrands_store_brand` → 500. `_set_position_optouts` had the identical
pattern.

## Fix
Added `session.flush()` between the delete loop and the insert loop in **both**
`_set_store_brands` and `_set_position_optouts`, so the DELETEs hit the database
before the INSERTs. One line each; no schema change.

## Follow-up worth doing
This delete-then-re-add-in-one-flush pattern has now bitten three helpers
(user_roles, store_brands, position_optouts). Any future "replace a set of
child rows" helper should either flush between delete/insert or diff the set.

## Rollback
- Remove the two `session.flush()` lines (reintroduces the bug).
