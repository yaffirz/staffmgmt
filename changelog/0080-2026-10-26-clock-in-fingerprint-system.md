# Changelog 0080 — Basic clock-in system + fingerprint enrolment

- **Timestamp:** 2026-10-26 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A basic clock-in system + page for the Non-Oracle roster, plus an easy
  way to register / modify / remove an employee's fingerprints. Phase 2 of the
  Non-Oracle feature (0078), toward a DigitalPersona-4500 clock-in.
- **Status:** Applied (backend + frontend). Verified via API and in-browser.
- **Decisions (from the user):** capture is **pluggable with a dev fallback** (no
  reader wired yet — enrolling stores a stand-in template; the kiosk can simulate
  a scan); clock-in page is a **no-login kiosk**; roster is **Non-Oracle only**
  for now; plus a **manager-assisted** path so a store manager can clock staff in
  from their own account when someone can't scan.

## Data model (new tables — auto-created, no migration)
- **`fingerprints`** — `employee_id`, `finger_label` (unique per employee),
  `template` (opaque; dev stand-in token), timestamps, `created_by`.
- **`clock_events`** — `employee_id`, `event_type` (in/out), `occurred_at`,
  `source` (kiosk/manager/dev), `recorded_by`, `note`.
- Settings: `clock_in_enabled` (master, default on) and `clock_dev_mode` (kiosk
  simulate, default on — **turn off in production**).

## Backend
- **`routes/fingerprints.py`** — enrol / list / modify (re-scan + re-label) /
  remove, Super Admin/Admin/IT, scoped to Non-Oracle employees. Omitted template →
  a dev stand-in token. `FINGER_LABELS` shared with the UI.
- **`routes/clock.py`**:
  - Kiosk (**no auth**): `GET /config`, `GET /roster` (dev-only, empty in prod),
    `POST /identify`, `POST /punch`. A fingerprint **template match** is the real
    path; an `employee_id` is accepted only when dev mode is on (403 otherwise),
    so production needs a real match. Auto-toggles in/out from the last event.
  - `POST /manager-punch` (**auth**, Super Admin/Admin/IT/Area Manager/Store/
    Foodmall) — clock a Non-Oracle employee in/out on their behalf.
  - `GET /my-roster` — role-scoped roster with current status (admins see all;
    Store/Foodmall → their store; Area Manager → their brands' stores).
  - `GET /events` — recent events feed / basic timesheet.
- `non_oracle.employee_is_non_oracle` extracted as the shared membership check.
- Registered both routers in `main.py`.

## Frontend
- **`models/clock.dart`**, service methods (`clockConfig/roster/identify/punch/
  managerPunch/myRoster/events`, `fingerprints` CRUD), `Employee.nonOracleOverride`.
- **`screens/clock_kiosk_screen.dart`** — the no-login kiosk (fingerprint prompt;
  in dev a searchable simulate-scan picker) → status card → big Clock IN/OUT →
  confirmation. Linked from the **login screen** ("Clock-in station").
- **`screens/clock_manager_screen.dart`** — "Clock In Staff" (dashboard tile for
  the manager roles): roster with per-employee Clock in/out + a Recent events tab.
- **Non-Oracle screen** — a per-row **Manage fingerprints** action opens a dialog
  to register / re-scan / remove fingers.
- **Settings** — a "Clock-in" section with the two toggles.

## Verification
- **API:** enrol/list/modify/remove (dup → 409); kiosk identify + punch toggling
  in↔out; **real template match** records source `kiosk`; dev-off rejects a
  simulated punch (403) and unknown template → 404; manager-punch (source
  `manager`, with note); events feed; role-scoped my-roster.
- **In-browser:** manager clock-in (punch → status flip → Recent feed "by
  manager"); the **kiosk** end-to-end (simulate scan → Clock OUT → confirmation);
  the Non-Oracle table shows "In list via" + the row menu. Test fingerprints and
  clock events were cleaned back to zero afterward.
- `flutter analyze` clean (one pre-existing `withOpacity` info in login_screen);
  `flutter build web` ok; backend `compileall` + import check ok.

## Not in this change (future)
- **Real DigitalPersona 4500 capture** — needs the DP Lite Client WebSDK (a local
  agent) on each scanning machine; it drops into the pluggable `template` path.
- Phasing non-Oracle beyond the current roster; richer timesheets / exports.

## Note
- Brand **"Heroes" is currently marked Non-Oracle** (pre-existing test state).
  Unmark it on Admin → Non-Oracle Employees → Brands if unintended.

## Rollback
- Remove the two routers + screens/models/service additions, the Settings section,
  the login link and dashboard tile, the two settings keys; drop the `fingerprints`
  and `clock_events` tables. Delete this changelog.
