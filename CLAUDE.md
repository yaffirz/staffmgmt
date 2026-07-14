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
  Dart files live. (An old `frontend/` folder previously caused sync bugs — do
  NOT use it; it should be deleted.)
  - Start (plain terminal, from `C:\Projects\staffmgmt\staff_frontend`):
    `flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8000`
    then open http://localhost:5000.
  - New files/imports require a full restart or `flutter clean` + `flutter pub get`,
    not just hot reload.

## Conventions
- Dates display MM/DD/YYYY everywhere (incl. bulk); wire format YYYY-MM-DD.
- `tenant_id` is always derived from the JWT, never from the client (Phase 1: 1).
- Passwords hashed with bcrypt directly. bcrypt/JWT carry sub/user_id/role/tenant_id.
- Roles: Super Admin, Admin, HR, Area Manager. Footer "Created by Arif Asad Ali".
- Verify before delivering: Python `python3 -m compileall`; Dart via `flutter analyze`.

## Current state (see changelog/0001 for full baseline)
- Done: auth/roles; employees CRUD (wizard, list, edit, delete, additional stores);
  configurable new-hire form; brands/stores/positions hub (add/edit/bulk/multi-delete
  with referential-integrity blocking); bulk import for all entity types (template
  download + file upload + paste); Users & Roles (email required+unique, AM multi-brand
  picker, role-grouped list); Area Manager "My Cluster" READ view (Phase 2a).
- Area Manager scoping is BRAND-based: an AM covers one or more brands (assigned by
  Admin/Super Admin in Users & Roles). Their cluster = all stores in those brands; a
  staff member appears under a store if it's their primary OR additional store.
- `area_manager_brands` table holds AM↔brand links. `area_manager_stores` exists but
  is currently unused.

## Next planned work
- Phase 2b: Move Staff + Request Staff flows (staff name search → name/brand/stores;
  request queued to admins/IT via notifications). Buttons already stubbed on the
  My Cluster store cards.
- Phase 3: status changes (promote/demote/transfer/terminate → `staff_status_log`),
  staff notes, notifications inbox.
- Admin mini-console for logs/activity (standing rule 3).
- `employees` needs an `employment_status` column for Terminate (add non-destructively).
