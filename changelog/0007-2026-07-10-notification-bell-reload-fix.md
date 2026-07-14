# Changelog 0007 — Fix: notification dropdown stuck on "Could not load"

- **Timestamp:** 2026-07-10 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** The bell dropdown showed "Could not load notifications." even though
  the API was healthy.
- **Status:** Applied on disk; `flutter analyze` clean (1 pre-existing info note).

## Root cause
The endpoint was fine — curl and the browser both returned 200 (`GET
/api/v1/notifications`), and unread-count returned 200 (`count:0`). The failure
was a **transient 401 on first load whose error state got cached**: `MenuAnchor`
keeps its menu child's `State` alive, so `_NotificationPanel.initState` ran only
once. A momentary auth blip during that first load left the FutureBuilder in an
error state that never refetched on reopen.

## Fix
- **Reload on every open:** the bell now bumps an `_openSeq` counter when the menu
  opens and passes it as the panel's `ValueKey`, forcing a fresh `State` (and a
  fresh load) each time — no more stuck state.
- **Retry affordance:** the panel's error state now shows a "Retry" button so any
  load failure is always recoverable without closing/reopening.
- `_NotificationPanel` constructor now accepts `super.key`.

## Files touched
- staff_frontend/lib/widgets/notification_bell.dart — open-seq key, reload-on-open,
  Retry button, key on panel ctor

## Verification
- `flutter analyze` → clean apart from the pre-existing `withOpacity` info note.
- Backend confirmed healthy during diagnosis (200s in logs + curl).
- Client behaviour: reopening the dropdown always issues a fresh GET; a failed load
  offers Retry.

## Note
- This round edited only an existing file (no new files), so a **hot restart** (`R`
  in the running `flutter run`) is enough — a full stop/start isn't required.
- Badge shows 0 because superadmin's notifications are all marked read (from earlier
  testing). To see a non-zero badge + unread styling, either generate a new event
  as am_pizza via /docs, or:
  `docker compose exec db psql -U staffadmin -d staffmgmt -c "delete from notification_reads where user_id=(select user_id from users where username='superadmin');"`

## Deployment
- Built: no. Hot restart of the running frontend.
- Deployed to production: no
