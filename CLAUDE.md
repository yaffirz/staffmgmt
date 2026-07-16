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

## Next planned work
- (No committed backlog.) Candidate follow-ups: hide/filter terminated staff from
  active rosters; relabel/retire the dead admin "Notifications" dashboard tile
  (the bell supersedes it); make audit_logs tenant-scoped before multi-tenant.
