# Changelog 0008 — Fix: notification dropdown closed immediately on open

- **Timestamp:** 2026-07-10 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** After 0007, clicking the bell opened and instantly closed the dropdown,
  so the notification list was never visible.
- **Status:** Applied on disk; `flutter analyze` clean (1 pre-existing info note).

## Root cause
0007's "reload on every open" trick called `setState(() => _openSeq++)` inside the
bell's `onPressed` right before `controller.open()`, and passed `_openSeq` as the
panel's `ValueKey`. That `setState` rebuilds the `MenuAnchor` at the instant it
opens, which dismisses the just-opened menu. The reload approach fought MenuAnchor.

## Fix (replaces the 0007 approach)
- Reverted the bell's `onPressed` to a plain open/close toggle; removed `_openSeq`
  and the panel `ValueKey`.
- Added an explicit **Refresh** icon button in the panel header (alongside
  "Mark all read"), so the list is refreshable on demand without rebuilding the
  anchor. The **Retry** button on the error state (from 0007) is kept.
- The panel still auto-loads on open (initState) and reloads after mark-read.

## Files touched
- staff_frontend/lib/widgets/notification_bell.dart — remove open-seq/key hack,
  restore simple toggle, add header Refresh button

## Verification
- `flutter analyze` → clean apart from the pre-existing `withOpacity` info note.
- Behaviour expected after hot restart: bell opens and stays open; list renders the
  3 items; Refresh re-fetches; Mark all read clears the badge.

## Note
- Existing file edit only → **hot restart** (`R`) is sufficient.

## Deployment
- Built: no. Hot restart of the running frontend.
- Deployed to production: no
