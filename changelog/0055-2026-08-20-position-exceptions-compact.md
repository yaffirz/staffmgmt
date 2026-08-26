# Changelog 0055 — Compact "with exceptions" label for universal positions

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A universal position with per-brand opt-outs rendered a long
  "All brands except A, B, C, D, E" label. Show something compact instead.
- **Status:** Applied (frontend only). `flutter analyze` clean (one pre-existing
  lint elsewhere); built + deployed.

## Change (`screens/org_child_list_screen.dart`)
- Row label for a universal position with opt-outs is now
  **"All brands · with exceptions"** (was the full excepted-brand list);
  "All brands" still shows when there are none.
- The excepted brands moved to a **tooltip** on that label — hover (desktop) or
  long-press (touch) reveals "Not available to: A, B, C". A plain tap still opens
  the row's editor (the per-brand on/off switches), i.e. "view more".

## Context
Per the decision to keep universal positions and curate them per brand via
opt-outs; this only changes how the opt-out summary is displayed. The new-hire
wizard already hides opted-out roles for a brand (via `availableForBrand`).

## Rollback
- Revert the single-file edit.
