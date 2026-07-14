# Changelog 0006 — Notification bell + inbox dropdown (frontend)

- **Timestamp:** 2026-07-10 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add the topbar notification bell + dropdown inbox (Flutter), consuming
  the inbox API from changelog 0005.
- **Status:** Applied on disk; `flutter analyze` clean. **Live browser verification
  pending a frontend restart** (new files → hot reload insufficient).

## What changed
- **Model** (`models/app_notification.dart`, new): `AppNotification` with
  `fromJson` and human-readable `title`/`body`/`ageDisplay`. Renders `STAFF_MOVED`
  and `STAFF_REQUESTED`; unknown types fall back to a prettified type + raw payload.
- **Service** (`services/staff_service.dart`): `notifications({unreadOnly})`,
  `unreadNotificationCount()`, `markNotificationRead(id)`, `markAllNotificationsRead()`.
- **Widget** (`widgets/notification_bell.dart`, new): `NotificationBell` —
  a `MenuAnchor` dropdown; bell shows a `Badge` with the unread count, polled every
  60s and after any read action. Panel (width 360, max height 420) lists
  notifications newest-first with unread highlight + dot, tap-to-read, and a
  "Mark all read" button. Empty/loading/error states handled.
- **Wiring** (`screens/dashboard_screen.dart`): `NotificationBell` added as the
  first topbar action (left of the theme toggle).

## Files touched
- staff_frontend/lib/models/app_notification.dart — NEW
- staff_frontend/lib/widgets/notification_bell.dart — NEW
- staff_frontend/lib/services/staff_service.dart — 4 notification methods + import
- staff_frontend/lib/screens/dashboard_screen.dart — bell in appBar + import

## Verification
- `flutter analyze` on the 4 files → no errors/warnings. Two `info`-level
  `withOpacity` deprecations (newer Flutter prefers `withValues`); kept `withOpacity`
  to match existing usage in dashboard_screen.dart.
- Browser drive NOT yet done — the running dev server on :5000 needs a full restart
  to load the new files. Expected: superadmin sees a badge of 3 (or current unread),
  dropdown lists the STAFF_MOVED + STAFF_REQUESTED items; am_pizza sees none.

## Deployment
- Built: no. Frontend dev server restart required (human-triggered):
  `flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8000`
- Deployed to production: no
- Cloudflare purged: n/a

## Rollback
- Remove `notification_bell.dart` + `app_notification.dart`, revert the
  staff_service.dart and dashboard_screen.dart edits, restart the frontend.
