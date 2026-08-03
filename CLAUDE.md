# staffmgmt — project guide for Claude Code

Multi-tenant staff-management web app (restaurant/hospitality, Trinidad).
Owner: Arif Asad Ali.

## Standing rules (always follow)
1. **Changelog required.** Every committed update gets its own NEW file in
   `/changelog`, named `NNNN-YYYY-MM-DD-short-title.md` (zero-padded sequence;
   highest number = most recent). Never overwrite prior entries. **Review the most
   recent changelog file before making any modification.**
2. **Toggleable features get an admin toggle.** When adding any feature that can be
   toggled, also add an Admin/Super Admin control (in the admin menu) to toggle or
   customize it — unless explicitly told otherwise.
3. **Admin mini-console.** The admin menu should include a mini console to view
   platform logs and user interactions/activity (backed by `audit_logs` + activity).

## Stack & how to run
**Two separate servers run from two different directories — do not mix them up:**
- **Backend (Docker) runs from the PROJECT ROOT: `C:\Projects\staffmgmt`.**
  FastAPI + SQLModel + PostgreSQL via Docker Compose. The `docker-compose.yml`
  lives at the root, so all `docker compose ...` commands must be run from
  `C:\Projects\staffmgmt`.
  - Start (from `C:\Projects\staffmgmt`): `docker compose up -d`
    (add `--build` only after backend code/dep changes).
  - API: http://localhost:8000 — health `/health`, docs `/docs`.
  - DB shell: `docker compose exec db psql -U staffadmin -d staffmgmt -c "..."`
  - New tables are created by SQLModel `create_all` on startup WITHOUT wiping data.
    Existing-table COLUMN changes must be done non-destructively via
    `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` / `CREATE UNIQUE INDEX IF NOT EXISTS`
    (never `down -v`, which wipes data).
- **Frontend (Flutter web) runs from `C:\Projects\staffmgmt\staff_frontend`.**
  This is the ONLY canonical frontend source; `staff_frontend\lib` is where all
  Dart files live. (The old deprecated `frontend/` folder was removed — see
  changelog 0026.)
  - Start (plain terminal, from `C:\Projects\staffmgmt\staff_frontend`):
    `flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8000`
    then open http://localhost:5000.
  - New files/imports require a full restart or `flutter clean` + `flutter pub get`,
    not just hot reload.

## Conventions
- Dates display MM/DD/YYYY everywhere (incl. bulk); wire format YYYY-MM-DD.
- `tenant_id` is always derived from the JWT, never from the client (Phase 1: 1).
- Passwords hashed with bcrypt directly. bcrypt/JWT carry sub/user_id/role/tenant_id.
- Roles: Super Admin, Admin, HR, Area Manager, IT. Users may hold multiple roles
  (additional roles are Super-Admin-assignable only; effective roles = primary +
  additional, carried in the JWT). Footer "Created by Arif Asad Ali".
- Verify before delivering: Python `python3 -m compileall`; Dart via `flutter analyze`.

## Current state (baseline in changelog/0001; full history in changelog/*)
- Foundations: auth/roles; employees CRUD (wizard, list, edit, delete, additional
  stores); configurable new-hire form; brands/stores/positions hub; bulk import;
  Users & Roles.
- **Area Manager scoping is BRAND-based**: an AM covers one or more brands; their
  cluster = all stores in those brands. A staffer shows under a store if it's their
  primary OR an additional store. `area_manager_brands` holds AM↔brand links;
  `area_manager_stores` is unused.
- **Phase 2 (done):** My Cluster view; Move (change primary store) + Request staff;
  Cross-store Assignments (add additional stores, accumulative); admin toggle
  "Area Managers can move staff".
- **Staff notes (done):** per-note visibility — private (author + Super Admin) or
  shared by role/brand; individual staff page + an all-notes feed; `staff_notes_enabled`
  toggle.
- **IT role + multi-role (done):** IT is admin-lite; `user_roles` junction holds
  additional roles (Super-Admin-assigned); effective roles gate everything.
- **Phase 3 (done):** status changes — promote/demote (position) + terminate/
  reactivate (`employees.employment_status`) → `staff_status_log`; Status Changes feed.
- **Notifications (done):** per-user inbox (`notifications` + `notification_reads`)
  with a topbar bell; all 5 IT/manager triggers live — reviewed→AM, cross-store→IT,
  promote/demote/terminate→IT.
- **Admin mini-console (done):** `GET /api/v1/audit-logs` + Audit Logs screen
  (standing rule #3).
- **Maintenance mode (done):** `maintenance_mode`/`maintenance_message`/
  `maintenance_until` settings + admin toggle & duration picker (Settings);
  public `GET /api/v1/maintenance/status`; animated maintenance page gates field
  roles (HR, Area Manager) while Super Admin/Admin/IT keep access. Client-side
  enforcement (see changelog 0031).
- **Announcements (done):** Super Admin broadcasts a message to all users via the
  bell or a one-time popup — a broadcast Notification (`recipient_role="All"`,
  `type="ANNOUNCEMENT"`); popup dismissal reuses `notification_reads`
  (changelog 0032).
- **Branding (done):** custom `AppLogo` (CustomPainter — amber badge + a
  "team hierarchy" glyph) shared across login/server-setup/dashboard; matching
  SVG favicon + PWA icons; browser tab is "Staff Portal" (changelog 0033).
- **Single-origin serving + Cloudflare tunnel groundwork (done):** the backend
  serves the built Flutter web (`staff_frontend/build/web`, bind-mounted) at `/`
  so one origin serves UI + API; on web the app auto-uses its own origin. A
  profile-gated `cloudflared` service publishes it — `docker compose --profile
  tunnel up -d` with `TUNNEL_TOKEN` in `.env`. See `docs/CLOUDFLARE_TUNNEL.md`
  (changelog 0034). Live tunnel still needs the owner's Cloudflare token/hostname.

- **Login marketing block (done):** admin-editable promo area on the login
  screen (the previously-empty brand-panel space), shown desktop + mobile.
  `marketing_*` settings + public `GET /api/v1/marketing`; type text/image/embed
  (embed = a video/media URL). Web renders embeds in an iframe; native shows a
  link card (conditional import, APK-safe). Admin control in Settings →
  "Login marketing block" (changelog 0035).
- **Store & Foodmall roles (done):** store-level logins bound to one store
  (`store_users`) that see only that store's staff, restricted to **name + brand**
  (no position/pay/contact) via `GET /api/v1/store/summary`; can request staff be
  added (notifies Admins). A **foodmall** is a store flagged `is_foodmall` that
  carries multiple brands (`store_brands`, chosen at store creation); a Foodmall
  account sees staff grouped by brand. Both roles are blocked from the full
  employee/cluster endpoints. Created in Users & Roles with a store picker
  (changelog 0036).
- **Registration foundation (done):** public sign-up → email confirmation →
  admin approval, in a separate `registration_requests` table (existing login
  untouched). Email **sending is a stub** (`core/email.py` logs the confirm link)
  until the sending domain is configured; approve/reject in the admin
  "Registrations" screen; `registration_enabled` toggle (default off) in Settings
  (changelog 0037).

- **Admin hub + activity console (done):** the config/admin tiles (Users & Roles,
  Registrations, Audit Logs, Form Settings, Settings, Announcements) now live
  behind one **Admin** tile (`admin_hub_screen`); the main dashboard keeps
  Employees, Brands & Stores, Status Changes, Notifications. A read-only
  terminal-styled **Activity Console** streams the audit log (auto-refresh,
  pause/resume) — never a command shell. `widgets/module_card.dart` is shared
  (changelog 0038).
- **Database backups (done):** Super-Admin `pg_dump` backups — "Back up now" with
  an animated elapsed/indeterminate progress, server-side storage
  (`./backups` bind mount, gitignored), Super-Admin **download** (audited) +
  delete, and **scheduled** daily/weekly with retention via an in-app APScheduler
  (`core/backup.py`, `core/scheduler.py`, `routes/backups.py`, `Backups` table;
  `backup_schedule`/`backup_time`/`backup_retention` settings). Image adds
  `postgresql-client`; requires `docker compose build backend` (changelog 0039).

- **In-app APK download (done):** signed-in users get a "Get the Android app"
  card on the dashboard (web only) that downloads the latest published APK.
  Login-gated `GET /api/v1/app/{info,download}`; the APK is served read-only from
  `./public` (host mount, gitignored) — publish with `scripts/publish-apk.sh`
  after `flutter build apk`. `app_download_enabled` toggle in Settings
  (changelog 0040).

## Next planned work
- (No committed backlog.) Candidate follow-ups: hide/filter terminated staff from
  active rosters; relabel/retire the dead admin "Notifications" dashboard tile
  (the bell supersedes it); make audit_logs tenant-scoped before multi-tenant;
  optional server-side write-gating during maintenance; an admin
  manage/expire-announcements view.
