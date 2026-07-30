# Changelog 0031 — Maintenance mode (toggle + customizable window + animated page)

- **Timestamp:** 2026-07-17 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add a maintenance mode with an admin toggle, a customizable message
  and duration, and an animated maintenance page shown during the window.
- **Status:** Applied; backend restarted + curl-verified; frontend `flutter
  analyze` clean (pre-existing lints only); verified in-browser end-to-end.

## Design
- **Three settings** (in `app_settings`, via the existing settings machinery):
  - `maintenance_mode` — "true"/"false" toggle.
  - `maintenance_message` — optional custom text (empty → default copy).
  - `maintenance_until` — optional ISO-8601 end time; the Settings UI turns a
    chosen **duration from now** into this absolute timestamp; the page shows a
    live countdown to it (empty → no countdown).
- **Exempt roles:** Super Admin, Admin, IT keep full access during maintenance;
  **HR and Area Manager** (field roles) see the maintenance page.
- **Enforcement is client-side.** The Flutter app is the only client; the backend
  exposes a *public* status endpoint and the app gates on it. This is an
  availability/UX gate, not a security boundary — a direct API caller is not
  blocked. Server-side write-gating is a possible follow-up.

## Backend
- `app/core/app_settings.py`: added the 3 keys to `DEFAULTS`.
- `app/schemas/maintenance.py` (new): `MaintenanceStatus`.
- `app/api/routes/maintenance.py` (new): `GET /api/v1/maintenance/status`
  (unauthenticated) — resolves tenant 1 settings (Phase 1 single-tenant).
- `app/main.py`: registered the router.

## Frontend
- `models/maintenance_status.dart` (new); `StaffService.maintenanceStatus()`.
- `state/maintenance_provider.dart` (new): polls status every 45s, swallows
  errors (a blip never traps the app behind the page). Registered in `main.dart`.
- `screens/maintenance_screen.dart` (new): animated (rotating gear + pulsing halo,
  built-in animations only — no assets), custom message, live countdown, "Check
  again", and a log-out action.
- `screens/root_gate.dart`: maintenance gate — authenticated non-exempt users get
  the maintenance page; exempt roles and the login screen are unaffected.
- `screens/settings_screen.dart`: new **Maintenance mode** section — toggle,
  message field, duration dropdown (No end time / 15m / 30m / 1h / 2h / 4h) +
  Save, and a "Window ends: MM/DD/YYYY HH:MM" readout.

## Verification
- curl: status reflects settings; toggling on/off works.
- Browser: Settings section renders and saves; toggle shows the "field users are
  now blocked" snackbar and the window-end readout; an Area Manager (am_pizza) is
  shown the animated page with a live countdown (28m 44s → 28m 34s) and can log
  out; Super Admin keeps full access.

## Deployment
- Built: no. Backend restarted. Frontend full restart (new files). Prod: no.

## Rollback
- Revert the edits; remove the maintenance route/schema/model/provider/screen and
  the Settings section. The 3 settings rows are harmless if left in `app_settings`.
