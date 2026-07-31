# Changelog 0039 — Database backups (manual, download & scheduled)

- **Timestamp:** 2026-07-31 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A "Back up now" button with a live progress/elapsed indicator,
  server-side storage with a Super-Admin download, and scheduled daily/weekly
  backups with retention.
- **Status:** Applied; backend verified end-to-end (manual run, download, delete,
  403 gating, **scheduler fired** a scheduled backup); `flutter analyze` clean;
  web rebuilt; backend image rebuilt.

## Security
- A dump contains **all data incl. password hashes** — every backup endpoint is
  **Super Admin only**; downloads are gated + audit-logged; the `backups/` folder
  is gitignored.

## Backend
- **Image:** `Dockerfile` adds `postgresql-client` (pg_dump); `requirements.txt`
  adds `APScheduler`. `docker-compose.yml` bind-mounts `./backups:/code/backups`
  (+ `BACKUP_DIR`), so dumps persist on the host.
- **Model** (`models.py`, create_all): `Backups` (filename, status
  running|completed|failed, kind manual|scheduled, size_bytes, created_by, timing,
  error).
- **`core/backup.py`:** runs `pg_dump` (arg list, no shell; `PGPASSWORD` from the
  parsed `DATABASE_URL`) in a **background thread** so the request returns at once;
  updates the row; `prune(retention)` deletes oldest files + rows.
- **`core/scheduler.py`:** an APScheduler `BackgroundScheduler` started in the
  `main.py` lifespan; reads `backup_schedule` / `backup_time` /
  `backup_retention` (app_settings) and registers a daily/weekly cron job that
  backs up + prunes. `reschedule()` on schedule change. (Single uvicorn worker →
  one scheduler.)
- **`routes/backups.py`** (Super Admin): `POST` (start), `GET` (list), `GET /{id}`
  (poll status), `GET /{id}/download` (FileResponse, audited), `DELETE /{id}`,
  and `GET/PUT /schedule`. Registered in `main.py`. `app_settings` defaults:
  `backup_schedule=off`, `backup_time=02:00`, `backup_retention=10`.

## Frontend
- `models/backup_item.dart`; `staff_service` methods; `api_client.getBytes` (raw
  download); `services/file_download*.dart` (conditional import — web triggers a
  browser save, native hides Download).
- `screens/admin_backups_screen.dart`: **Back up now** → poll status → an
  **animated indeterminate bar + live elapsed-seconds timer** while running, then
  size + duration. List with **Download** (web, Super Admin) + Delete. A schedule
  card (Off/Daily/Weekly + time + retention). Reached from the Admin hub.

## Verification
- Manual: run → `.sql` (66 KB) written to `./backups`, row completed with
  size/duration; download returned valid SQL; delete removed it; non-Super-Admin →
  403. Scheduled: set daily one minute out → the job fired and created a
  `scheduled` backup automatically.

## Notes
- `pg_dump` has no progress %, so the UI uses an indeterminate bar + elapsed timer
  (documented in-UI). Restores are manual from the dump for now.

## Deployment
- Built: backend image + web rebuilt; containers recreated. Live via tunnel.

## Rollback
- Revert edits; drop `routes/backups.py`, `core/backup.py`, `core/scheduler.py`,
  the `Backups` table, the compose mount, and the Dockerfile/requirements lines.
