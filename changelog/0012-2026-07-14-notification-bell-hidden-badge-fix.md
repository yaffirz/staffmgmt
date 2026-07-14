# Changelog 0012 — Fix: hidden Badge spammed layout errors when unread count = 0

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** After the 0011 dropdown fix, in-browser verification found the console
  still spamming `Cannot hit test a render box that has never been laid out` — but
  only when the unread badge was hidden (count 0).
- **Status:** Applied on disk; `flutter analyze` clean (1 pre-existing info note).

## How it was found
Verified in-browser (Claude driving the app). With the badge VISIBLE (count 3) a
fresh reload produced no such errors; with the badge HIDDEN (count 0) the error
recurred every frame, above the app-start logs (i.e. live, not stale buffer).

## Root cause
The anchor rendered `Badge(isLabelVisible: count > 0, label: Text('$count'), ...)`.
When `isLabelVisible` is false, the Badge still builds its label render box but
doesn't lay it out, while hit-testing (pointer/hover over the app bar) still probes
it — throwing the caught exception continuously. Non-fatal but noisy and wasteful.

## Fix
Render the **bare `IconButton`** when `count == 0`, and only wrap it in a `Badge`
when `count > 0` (no `isLabelVisible: false` path). The switch happens inside the
`ValueListenableBuilder`, so it repaints only the badge subtree — the `MenuAnchor`
is untouched and an open menu won't close (the 0009 property is preserved).

## Files touched
- staff_frontend/lib/widgets/notification_bell.dart — conditional bare-button vs Badge

## Verification
- `flutter analyze` → clean apart from the pre-existing `withOpacity` info note.
- 0011 dropdown fix already confirmed working in-browser: bell opens and stays open,
  lists notifications with readable text, unread→read on Mark all read, badge clears.
- This hidden-badge fix needs one more frontend hot restart to confirm the console
  is clean at count 0.

## Deployment
- Built: no. Frontend hot restart required to load this fix.
- Deployed to production: no

## Rollback
- Revert the notification_bell.dart builder edit.
