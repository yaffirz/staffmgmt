# Changelog 0084 — Kiosk fingerprint scan → identify → clock in/out

- **Timestamp:** 2026-10-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** The kiosk only had the dev "pick an employee" simulate path — add the
  real **scan-a-fingerprint** flow: capture → identify who it is (1:N) → clock
  them in/out.
- **Status:** Applied (backend + frontend). Identify verified via API on a real
  enrolled PNG; frontend builds.

## Backend
- **`core/matcher.py`** — shared client for the matcher microservice
  (`verify(probe, candidates)`).
- **`routes/clock.py`** — `_identify_by_scan` matches a captured scan against
  **all** enrolled Non-Oracle fingerprints (sends every stored sample to the
  matcher, maps the best hit back to its employee; 404 if no confident match).
  Two public endpoints:
  - `POST /clock/identify-scan {sample}` → who it is + clock status (no punch).
  - `POST /clock/punch-scan {sample}` → identify + record the next in/out (source
    `kiosk`). Identity always comes from the scan (never a client-supplied id), so
    these stay safe on the no-login kiosk.

## Frontend
- **`clock_kiosk_screen.dart`** — the fingerprint is now a **tappable "Scan
  fingerprint"** button. Tapping it captures a print (DigitalPersona Web SDK),
  calls `identify-scan`, and shows the matched employee's card; **Clock In/Out**
  then calls `punch-scan` (re-matches the same scan). The dev "simulate a scan"
  picker remains below when `clock_dev_mode` is on. Shows "Fingerprint not
  recognised" when no match.
- Service: `clockIdentifyScan`, `clockPunchScan`.

## Verification
- **API:** `identify-scan` with a real enrolled sample returned the right
  employee + status (1:N match via the matcher). `flutter analyze` clean;
  `flutter build web` ok; backend `compileall` ok.
- **Note (scale):** identify extracts a template per enrolled sample on each scan;
  fine for now, cache templates if the enrolled set grows large.

## Rollback
- Remove the two endpoints + `_identify_by_scan` + `core/matcher.py` use here and
  revert the kiosk scan button; delete this changelog.
