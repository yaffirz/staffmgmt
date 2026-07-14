@echo off
REM ---------------------------------------------------------------------------
REM staffmgmt dev launcher — opens the two servers in two separate terminals.
REM   Terminal 1: backend  (FastAPI + Postgres via Docker Compose, from root)
REM   Terminal 2: frontend (Flutter web-server on http://localhost:5000)
REM Close a window (or Ctrl+C in it) to stop that server.
REM ---------------------------------------------------------------------------

start "staffmgmt backend (docker)" cmd /k "cd /d %~dp0 && docker compose up"

start "staffmgmt frontend (flutter)" cmd /k "cd /d %~dp0staff_frontend && flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8000"

echo Launched backend and frontend in separate terminals.
