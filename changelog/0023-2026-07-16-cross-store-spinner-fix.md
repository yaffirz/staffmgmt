# Changelog 0023 — Fix: cross-store Assign button stuck spinning

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif (found during in-browser verification)
- **Task:** After a successful cross-store assign, the Assign button kept showing
  its progress spinner (disabled) even though the assignment had succeeded.
- **Status:** Applied on disk; `flutter analyze` clean. Loads on next frontend
  hot restart.

## Cause
`_assign()` set `_submitting = true` but only reset it in the error paths — on
success it awaited `_load()` and returned without resetting, leaving the button
stuck.

## Fix
Reset `_submitting = false` after the successful `_load()` in
`screens/cross_store_screen.dart`.

## Verification
- In-browser: am_pizza assigned 1234 → San Fernando; the staffer's stores updated
  to "Chaguanas, San Fernando" (accumulative) and the store list emptied
  correctly. `flutter analyze` → No issues found.

## Deployment
- Built: no. Frontend hot restart to load.
- Deployed to production: no

## Rollback
- Revert the one-line edit.
