# Changelog 0038 — Admin hub + activity console

- **Timestamp:** 2026-07-31 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Declutter the Super Admin/Admin dashboard by gathering the config/admin
  tools behind one **Admin** tile, and add a **read-only activity console**
  (terminal-styled live feed) — the "mini console" from standing rule #3.
- **Status:** Applied; `flutter analyze` clean; web rebuilt. Backend unchanged
  (console reuses `GET /api/v1/audit-logs`).

## Admin hub
- `widgets/module_card.dart` (new): the dashboard tile extracted so the dashboard
  and the hub share it.
- `dashboard_screen.dart`: rewritten — Admin & Super Admin now see **Employees,
  Brands & Stores, Status Changes, Notifications, and one "Admin" tile**. The
  config tools moved into the hub.
- `screens/admin_hub_screen.dart` (new): a sub-dashboard with **Users & Roles,
  Registrations, Audit Logs, Activity Console, Form Settings, Settings**, plus
  **Announcements** and **Backups** (both Super Admin only, gated via
  `AuthProvider`).

## Activity console
- `screens/admin_console_screen.dart` (new): a dark, monospaced, **read-only**
  feed of platform activity — one coloured line per audit entry
  `HH:MM:SS user ACTION table#id  summary` (green/blue/red by action). Auto-
  refreshes every 4s with a Live/Paused toggle. **No command input** (never a
  shell). Reuses `staff_service.auditLogs()`.

## Files touched
- staff_frontend/lib/widgets/module_card.dart (new)
- staff_frontend/lib/screens/admin_hub_screen.dart (new),
  admin_console_screen.dart (new)
- staff_frontend/lib/screens/dashboard_screen.dart (rewritten)

## Deployment
- Built: web rebuilt. Live via tunnel. Prod: yes.

## Rollback
- Restore the previous `dashboard_screen.dart` (all tiles top-level); delete the
  hub + console screens and `module_card.dart`.
