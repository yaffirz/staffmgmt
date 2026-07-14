# Changelog 0011 — Fix (real root cause): dropdown invisible due to ListView in MenuAnchor

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** The notification dropdown appeared to "close immediately" when the
  badge was non-zero, so the list was never visible.
- **Status:** Applied on disk; `flutter analyze` clean (1 pre-existing info note).
  Confirmed the failure in-browser via console; fix pending a frontend reload.

## Root cause (confirmed, with console evidence)
Driving the app in a browser and reading the console showed, repeated every frame:
`Cannot hit test a render box that has never been laid out.`

The dropdown was NOT closing — it opened but failed to lay out (so it was
invisible). `MenuAnchor` sizes its menu to content by measuring **intrinsic
height**, and the panel's data branch used a **`ListView`**, which does not support
intrinsic sizing. Layout threw, the render box was never laid out, and every
subsequent hit-test (mouse move) threw again.

This explains all prior confusion:
- Badge 0 / error / empty state → intrinsic-safe (`Text`/`Padding`) → visible.
- Badge > 0 / data → `ListView` branch → layout fails → invisible.

The earlier fixes (0007 reload-on-open, 0008 revert, 0009 ValueNotifier) chased the
wrong symptom. 0009's ValueNotifier is still a valid improvement and is kept.

## Fix
Replaced the `ConstrainedBox` + `ListView.separated` data branch with an
intrinsic-safe, non-scrolling `Column`:
- Shows up to 6 most-recent notifications (dropdown shape), with dividers.
- If there are more, a "+ N more" footer row is appended.
- Loading / error / empty branches unchanged (already intrinsic-safe).

## Files touched
- staff_frontend/lib/widgets/notification_bell.dart — ListView → capped Column

## Verification
- `flutter analyze` → clean apart from the pre-existing `withOpacity` info note.
- In-browser: reproduced the "never been laid out" console error on click (old
  bundle). Re-confirmation of the fix requires the frontend to reload the new code
  (`flutter run` does not auto-reload on save — hot restart with `R`, or restart
  the frontend server).

## Deployment
- Built: no. Frontend hot restart / reload required to load the fix.
- Deployed to production: no

## Rollback
- Revert the notification_bell.dart edit.
