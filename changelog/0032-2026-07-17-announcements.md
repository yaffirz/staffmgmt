# Changelog 0032 — Announcements (bell broadcast or one-time popup)

- **Timestamp:** 2026-07-17 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Let the Super Admin broadcast a custom message to all users, either
  pushed to the notification bell or shown as a one-time on-screen popup.
- **Status:** Applied; backend restarted + curl-verified; frontend `flutter
  analyze` clean (pre-existing lints only); verified in-browser end-to-end.

## Design
- An announcement is a **Notification** with `type="ANNOUNCEMENT"` and a broadcast
  recipient `recipient_role="All"`, so it reuses the whole notification inbox +
  per-user read-state machinery. `payload.display` selects the channel:
  - **"bell"** — appears in every user's bell inbox (like any notification).
  - **"popup"** — ALSO surfaces once as a dialog the next time each user opens the
    app; dismissal is the normal per-user read (`notification_reads`), so it never
    reappears. The popup copy also stays in the bell as a record.
- **Only Super Admin** may create announcements.

## Backend
- `app/api/routes/notifications.py`: added `BROADCAST_ROLE = "All"` and included it
  in every user's `_visible_roles`, so an "All"-targeted notification reaches
  everyone (and the existing mark-read auth check accepts it).
- `app/schemas/announcement.py` (new): `AnnouncementCreate` (validates non-blank
  title/body and `delivery ∈ {bell, popup}`) + `AnnouncementResult`.
- `app/api/routes/announcements.py` (new):
  - `POST /api/v1/announcements` (Super Admin only) — creates the broadcast
    Notification, audit-logged.
  - `GET /api/v1/announcements/popup` — unread popup announcements for the caller
    (reuses `_my_notifications` / `_read_ids` from notifications.py).
- `app/main.py`: registered the router.

## Frontend
- `StaffService.createAnnouncement(...)` + `popupAnnouncements()`.
- `models/app_notification.dart`: renders `ANNOUNCEMENT` (title/body from payload)
  in the bell.
- `screens/authenticated_home.dart` (new): wraps the dashboard; on login/auto-login
  it fetches unread popup announcements and shows them as one-time dialogs, marking
  each read. `root_gate.dart` now returns this for authenticated users.
- `screens/announcements_screen.dart` (new): Super-Admin compose screen — title,
  message, delivery choice (bell / popup), Send.
- `screens/dashboard_screen.dart`: **Announcements** tile, **Super Admin only**
  (split from the shared Admin module list).

## Verification
- curl: bell + popup create; a field user (am_pizza) sees both in the bell
  (broadcast); the popup endpoint returns only the popup one; marking it read
  empties the popup queue; non-Super-Admin create → 403; blank title → 422.
- Browser: compose screen sends ("Announcement sent to all users."); the popup
  announcement shows as a one-time "Got it" dialog on load; announcements render
  in the bell (title + body) alongside staff notifications.

## Notes / follow-ups
- Announcements have no expiry/delete yet (a bell entry lingers until each user
  reads it). An admin "manage/expire announcements" view is a candidate follow-up.

## Deployment
- Built: no. Backend restarted. Frontend full restart (new files). Prod: no.

## Rollback
- Revert the edits; remove the announcements route/schema/screens. The
  `BROADCAST_ROLE` change is small and self-contained.
