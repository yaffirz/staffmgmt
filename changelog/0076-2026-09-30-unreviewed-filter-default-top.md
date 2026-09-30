# Changelog 0076 — "Unreviewed" filter + unreviewed rows default to the first page

- **Timestamp:** 2026-09-30 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add an **Unreviewed** filter option, and make it the default that **all
  unreviewed rows show on the first page** so reviewers can work through them.
- **Status:** Applied (frontend only). Verified via `flutter analyze` + `flutter build web`.

## What changed
### "Unreviewed" filter
- **`screens/employees_list_screen.dart`:** the existing review-status filter that
  meant `reviewed == false` was labelled **"Pending review"** — it already *was*
  the unreviewed filter, so it's been **relabelled "Unreviewed"** for clarity
  (single source of truth, no confusing duplicate). Renamed in all three places:
  the quick-filter chip, the **Review status** dropdown option, and the active
  filter chip. Behaviour is unchanged (`reviewed == false`); "Reviewed" is
  untouched.

### Unreviewed rows default to the first page
- **`_applyFilter` (the list's `DataTableSource`):** the default sort now floats
  **every** unreviewed row ahead of reviewed rows (previously only *recently
  changed* unreviewed rows were bumped). Order within the result:
  1. recently-changed unreviewed rows (edits / promotions / store adds), most
     recent first (by `updatedAt`);
  2. the remaining unreviewed rows, original order;
  3. reviewed rows, original order.
  So reviewers see all outstanding rows on page 1 without paging or filtering.
  Applies to **both** the table and card views (they share this source).

## Verification
- `flutter analyze` — only the 2 pre-existing `use_build_context_synchronously`
  infos and one `withOpacity` info (unchanged codebase style).
- `flutter build web` — ok.

## Rollback
- Revert the label changes and restore the previous two-bucket sort, and delete
  this changelog.
