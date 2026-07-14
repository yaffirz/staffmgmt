# Changelog 0009 — Fix: bell menu closed on open once unread count > 0

- **Timestamp:** 2026-07-10 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Clicking the bell still opened-then-immediately-closed the dropdown
  (only once the badge was non-zero), so the list was never visible.
- **Status:** Applied on disk; `flutter analyze` clean (1 pre-existing info note).

## Root cause (the real one)
The unread count was stored in `int _unread` and updated via `setState`. Every
count update — the initial fetch and each 60s poll — rebuilt the whole
`MenuAnchor`, which dismisses an open menu. This only manifested once the count
became non-zero (which is why it stayed open earlier when the badge was 0 and no
`setState` changed the value). This is the well-known MenuAnchor pitfall: rebuild
the anchor while open → the menu closes.

0007/0008 chased the wrong mechanism (reload-on-open); this addresses the rebuild.

## Fix
- Count now lives in a `ValueNotifier<int>`; `_refreshCount` sets `.value` (no
  `setState`), so the `MenuAnchor` never rebuilds on count changes.
- The badge is wrapped in a `ValueListenableBuilder`, so only the badge subtree
  repaints when the count changes.
- The anchor is a **stable `Badge`** (`isLabelVisible: count > 0`) rather than
  switching between a bare button and a Badge — no structural change either.
- Notifier disposed in `dispose`.

## Files touched
- staff_frontend/lib/widgets/notification_bell.dart — ValueNotifier count,
  ValueListenableBuilder badge, stable Badge anchor

## Verification
- `flutter analyze` → clean apart from the pre-existing `withOpacity` info note.
- Expected after hot restart: bell opens and STAYS open with a non-zero badge;
  list shows the 3 items; Mark all read clears the badge without closing the menu.
- Not yet browser-confirmed on my side (user drives :5000). If it still closes,
  next step is to inspect the browser console for an exception during menu build.

## Note
- Existing file edit only → **hot restart** (`R`) is sufficient.

## Deployment
- Built: no. Hot restart of the running frontend.
- Deployed to production: no
