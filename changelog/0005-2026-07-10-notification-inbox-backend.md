# Changelog 0005 — Notification inbox (backend read-side)

- **Timestamp:** 2026-07-10 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add the read-side for notifications (bell/inbox), so the events
  already written by Move/Request (and future triggers) are viewable in-app.
  Frontend bell/panel is a separate later entry.
- **Status:** Applied (dev backend reloaded + verified). Not a production deploy.

## Context
The `notifications` table exists and is already populated (STAFF_MOVED /
STAFF_REQUESTED), but there was no way to read it in-app. This adds the inbox API.
Chosen as step 1 of the larger notification feature; the 5 requested triggers
depend on prerequisites not yet built (IT role + multi-role, a scheduler, and
Phase 3 status changes) and are deferred.

## Design decision — per-user read state
Notifications broadcast to a role (e.g. all Admins), so a single `is_read` flag
would let one recipient's read hide the badge for everyone. Added a
`notification_reads(notification_id, user_id)` junction; "unread for me" = no read
row for me. The legacy `notifications.is_read` column is left unused (harmless).

Targeting rule: a notification is visible to a user if `recipient_user_id == me`,
or (`recipient_user_id` is null and `recipient_role` is in the user's visible
roles). Super Admin's visible roles include "Admin" (hierarchy superset); this
generalises to a union over roles once multi-role lands.

## What changed
- **Models** (`models/models.py`): added `NotificationReads` table (unique
  `(notification_id, user_id)`), auto-created by create_all.
- **Schemas** (`schemas/notification.py`, new): `NotificationRead`, `UnreadCount`.
- **API** (`routes/notifications.py`, new), any authenticated user:
  - `GET /api/v1/notifications?unread_only=` — my notifications, newest first, cap 100.
  - `GET /api/v1/notifications/unread-count` — badge count.
  - `POST /api/v1/notifications/{id}/read` — mark one read (must target me; else 404).
  - `POST /api/v1/notifications/read-all` — mark all mine read.
- **Wiring** (`main.py`): registered the notifications router.

## Files touched
- backend/app/models/models.py — NotificationReads table
- backend/app/schemas/notification.py — NEW
- backend/app/api/routes/notifications.py — NEW
- backend/app/main.py — register notifications router

## Verification (live dev backend)
- compileall clean; routes present in OpenAPI.
- superadmin (Super Admin): unread-count = 3 (all Admin-targeted); list shows
  STAFF_MOVED + 2×STAFF_REQUESTED; mark one → 2; read-all → 0; unread_only → [].
- am_pizza (Area Manager): unread-count = 0; mark-read on an Admin notification → 404.
- `notification_reads` holds only superadmin's rows → per-user read confirmed.

## Deployment
- Built: no (volume-mounted; `docker compose restart backend`, uvicorn --reload).
- Deployed to production: no
- Cloudflare purged: n/a

## Rollback
- Remove `routes/notifications.py`, `schemas/notification.py`, revert models.py +
  main.py, restart backend. `notification_reads` table can be left (harmless).
