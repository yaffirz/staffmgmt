# Changelog 0082 — Attendance register (weekly, per store) + simple scheduling

- **Timestamp:** 2026-10-27 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Format the clock-in data like the paper **Attendance Register**: per
  store, Monday–Sunday, each employee with **Roster · IN · OUT · Hours**, with
  **simple scheduling** for the Roster column and **print/PDF** output.
- **Status:** Applied (backend + frontend). Backend verified via API; frontend
  analyzes + builds.

## Scheduling
- New **`shifts`** table (`employee_id`, `work_date`, free-text `roster` e.g.
  "7-3pm"/"OFF"/"VACATION"; unique per employee+date). Auto-created.
- `PUT /api/v1/attendance/shift {employee_id, work_date, roster}` upserts a roster
  cell (blank clears it). Editable inline in the register.

## Attendance register
- `routes/attendance.py`: `GET /register?store_id=&week_start=` builds the weekly
  grid — for each **Non-Oracle** employee whose primary store is the selected one,
  each day shows the **roster** (scheduled) plus the **IN** (first scan) / **OUT**
  (last scan) / **Hours** (OUT−IN) from `clock_events`, and a weekly total. Times
  are converted to local **AST (UTC-4)**. `GET /stores` lists the stores the user
  may view (role-scoped via the clock manager scope). Roles: Super Admin / Admin /
  IT / Area Manager / Store / Foodmall.

## Frontend
- **`screens/attendance_register_screen.dart`**: a **Attendance Register**
  dashboard tile (clock-capable roles). Store dropdown + week navigation; each
  employee is a card with a Day/Date/Roster/IN/OUT/Hours table + total, formatted
  like the paper. Tapping a **Roster** cell edits the shift.
- **Print / PDF**: `attendance_pdf.dart` builds a paper-style PDF with the `pdf`
  package (pure Dart) and opens it in a new browser tab to print or save
  (`services/pdf_open*.dart`, conditional-import, web-only). Avoids the native
  `printing` plugin (which needs Windows Developer Mode/symlinks).

## Verification
- **API:** set a roster ("7-3pm") + inserted IN 07:00 / OUT 15:00 AST for a
  Non-Oracle employee → `/register` returned that day with roster "7-3pm",
  IN "7:00 AM", OUT "3:00 PM", **Hours 8:00**, total 8:00; correct UTC→AST
  conversion; `/stores` role-scoped. `flutter analyze` (only benign infos: 2 const
  hints + the same `dart:html` infos as the existing download helper);
  `flutter build web` ok; backend `compileall` ok.

## Next / notes
- Roster is free text (matches handwritten shifts); a structured shift picker and
  per-day leave states could come later. IN = first scan, OUT = last scan of the
  day (breaks not itemised yet).

## Rollback
- Remove `routes/attendance.py` + the `shifts` table + the register screen/PDF/
  service bits + the dashboard tile + the `pdf` dependency; delete this changelog.
