# Changelog 0010 — Dev launcher (start-dev.bat)

- **Timestamp:** 2026-07-14 11:58 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add a batch file at the project root that starts both servers in two
  separate terminal windows.
- **Status:** Applied on disk. Not executed (starting servers is user-triggered).

## What changed
- Added `start-dev.bat` at the project root. Double-clicking it (or running it from
  a terminal) opens two new terminal windows via `start ... cmd /k`:
  - **Backend** — `docker compose up` from the project root (FastAPI + Postgres;
    runs in the foreground so the window shows logs).
  - **Frontend** — `flutter run -d web-server --web-port 5000
    --dart-define=API_BASE_URL=http://localhost:8000` from `staff_frontend`.
- Paths use `%~dp0` (the batch file's own directory) so it works regardless of the
  current working directory.

## Files touched
- start-dev.bat — NEW

## Notes / caveats
- If a Flutter server is already bound to :5000, the frontend window will fail to
  bind — stop the existing one first.
- `docker compose up` (foreground) attaches to logs; Ctrl+C stops the containers.
  Swap to `docker compose up -d` in the script if you prefer detached backend.
- Not run by me — the human triggers starting the servers.

## Deployment
- Built: no
- Deployed to production: no

## Rollback
- Delete start-dev.bat.
