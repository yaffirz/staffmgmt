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
  untouched). Approve/reject in the admin "Registrations" screen;
  `registration_enabled` toggle (default off) in Settings (changelog 0037).
- **Outgoing email / SMTP (done):** `core/email.py` sends real mail via `smtplib`
  (best-effort; still a safe no-op when disabled/unconfigured). Config lives in
  `app_settings` (`email_*`) and is managed from **Admin → Email** (Super Admin):
  server host/port, SSL vs STARTTLS, username, **write-only** password (never
  returned), From address/name, an **on/off toggle**, and a **Send test email**
  button that surfaces the real SMTP error. API: `GET/PUT /api/v1/email/config`,
  `POST /api/v1/email/test` (`routes/email_admin.py`). Setup steps in
  `docs/EMAIL.md` (Turbify = `smtp.bizmail.yahoo.com`, app-specific password)
  (changelog 0066).
- **Per-user email opt-in + password reset (done):** each account has a
  `users.email_opt_in` toggle in Users & Roles ("Receives platform email").
  Self-service reset: **Forgot password?** on login emails a **single-use,
  60-min** link (`/?reset_token=…`) → `ResetPasswordScreen` (intercepted in
  `RootGate` by query param) → new password. Endpoints
  `POST /api/v1/auth/forgot-password` (neutral response), `.../reset-password`,
  `GET .../reset-password/validate`; tokens in `password_reset_tokens`. Links use
  the `app_base_url` setting ("Public site URL" on Admin → Email; blank = derive
  from request). Email must be enabled (0066) to actually send (changelog 0067).
- **Editable email templates + signature (done):** Admin → Email → "Email
  content" edits a global **signature** and the **password-reset** subject/body,
  with reusable tags substituted at send time — `<username>`, `<email>`,
  `<reset_link>`, `<expiry_minutes>`, `<signature>`, `<from_name>`, `<site_url>`
  (`email_signature`/`email_reset_subject`/`email_reset_body` settings;
  `render_template` in `core/email.py`, single-pass, URL-safe). Reset body force-
  appends `<reset_link>` if omitted; registration + test emails append the
  signature (changelog 0068).
- **HTML emails + formatted signature (done):** `email_html` toggle ("Format
  emails as HTML" on Admin → Email). When on, emails are multipart (HTML + text
  fallback) and the signature can be HTML (bold/colour/links/images; images need
  public URLs). `compose_message` in `core/email.py` inserts the signature raw at
  `<signature>` (via a sentinel) while plain body text is escaped, URL-linkified,
  and newline→`<br>`. Signature field becomes "Signature (HTML)"; preview via
  Send test email (changelog 0069).

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

- **Country management (done):** add/edit/delete countries under Brands & Stores;
  feeds the staff-form Country field (changelog 0043).
- **Employee-list filters + UX (done):** filter All-employees by brand / store /
  position / country plus **who added / date added / date completed / month**,
  with preset quick-filters; tablet scrollbars + a quick-edit profile popup; and
  **Added / Added by / Completed** columns backed by `employees.created_by` and
  `employees.reviewed_at` (changelog 0044, 0046, 0047).
- **Universal positions (done):** a job role defined once, available to **all**
  brands with per-brand opt-outs (`positions.brand_id` nullable +
  `position_brand_optouts`). The opt-out summary reads "All brands · with
  exceptions" with the excepted brands on hover / long-press (changelog 0045, 0055).
- **Per-employee brand (done):** `employees.brand_id` (nullable) records which
  brand of a multi-brand **foodmall** a staffer belongs to; NULL falls back to the
  primary store's brand. Foodmall stores also appear under **every brand they
  carry** in the store pickers, not just the primary (`Store.servesBrand`)
  (changelog 0050, 0051).
- **"Email unavailable" flag (done):** a new-hire checkbox to add a staffer with
  no email (`employees.email_pending`); the row is flagged **amber**, IT gets an
  "Email not valid" dialog on review, and it **auto-clears** once an email is
  saved. `email_unavailable_enabled` toggle (changelog 0049).
- **Pay rate 0.00 flag + review block (done):** a 0.00 pay rate flags the
  employee row **amber** (same as no-email; amber wins over green) and **blocks
  marking it reviewed** — enforced in `set_reviewed` (400) and the list (a "Pay
  rate not set" dialog before the call). Un-reviewing is allowed; only an explicit
  0.00 is flagged (not None). `payrate_required_for_review` toggle in Settings
  (default on) (changelog 0070).
- **Global top bar (done):** the notification bell + theme toggle + log-out appear
  on **every** signed-in page (appended by `AppScaffold`), not just the dashboard
  (changelog 0054).
- **Force password change (done):** admin checkbox **"Require password change at
  next login"** (`users.must_change_password`); a forced-change screen gates the
  app until the user sets a new password; self-service `POST
  /api/v1/auth/change-password` clears it (changelog 0056).
- **Account suspension (done):** `users.suspended` — blocks login (403) **and**
  rejects a live session on its next request (enforced in `get_current_user`).
  Reversible; admin toggle in the user form + a "Suspended" badge; you cannot
  suspend your own account (changelog 0058).
- **IT can manage stores (done):** the IT role may **add / edit / delete stores**
  (`STORE_MANAGE_ROLES = Super Admin, Admin, IT`) and gets a Brands & Stores
  dashboard tile; brands / positions / countries stay Admin-only. Frontend edit
  rights are scoped to the Stores screen only (changelog 0059).
- **Login by username OR email (done):** the identifier is trimmed and matched
  **case-insensitively** against both `username` and `email`; the field is
  relabeled "Username or email" (changelog 0060).

## Known bugs fixed (Aug 2026)
- **Recurring "replace child rows" 500s.** A helper that *deletes all child rows
  then re-adds the wanted ones in one flush* hits a unique-constraint violation
  when a value is **retained** (SQLAlchemy emits same-table INSERTs before
  DELETEs). Fixed with a `session.flush()` between the delete and insert loops in
  every such spot: `user_roles` (0048), `store_brands` + `position_brand_optouts`
  (0052), `area_manager_brands` + Store/Foodmall store-link + employee
  additional-stores (0053). **When adding any new "replace a set of child rows"
  helper, flush between delete and insert (or diff the set).**
- **500 deleting a user** who had read/dismissed a notification (`notification_reads`)
  or had personal notifications — now cleaned up first (0057). *Known remaining
  limitation:* deleting a user who **authored staff notes** or processed **status
  changes** still fails (history FKs) — suspend them instead (0058), or a future
  change can reassign/nullify that history.
- **Filter dialog rendered as a blank grey box** — a `Spacer` inside
  `AlertDialog.actions` (an OverflowBar, not a Flex); release builds swallow the
  error into a grey `ErrorWidget` (0047).
- **Foodmall stores missing** under their extra carried brands in the pickers —
  the filter keyed on the primary brand only (0050).
- **Invisible password eye icons** — the `_outlined` visibility glyphs were
  dropped by the icon tree-shaker; switched to the non-outlined ones (0053).

## Stability
Platform is **stable**. Every schema change this cycle was **non-destructive**
(`ALTER TABLE … ADD COLUMN IF NOT EXISTS`, no `down -v`, no data loss) and each
change was verified before commit — backend flows end-to-end against the running
API, frontend via `flutter analyze` + `flutter build web`, and the key flows
(suspension live cut-off, forced password change, employee filters, IT store
access, username/email login) confirmed in-browser. One changelog file per commit
(standing rule #1); highest number = newest (currently **0060**).

## Next planned work
- (No committed backlog.) Candidate follow-ups: hide/filter terminated staff from
  active rosters; relabel/retire the dead admin "Notifications" dashboard tile
  (the bell supersedes it); make audit_logs tenant-scoped before multi-tenant;
  optional server-side write-gating during maintenance; an admin
  manage/expire-announcements view; a global "kick to login on 401/403" so a
  suspended user is bounced instantly without a reload; clean up authored-history
  FKs so a content-authoring user can be hard-deleted (or standardise on suspend).
