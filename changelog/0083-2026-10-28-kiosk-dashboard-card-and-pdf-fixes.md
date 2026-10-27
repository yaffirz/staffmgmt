# Changelog 0083 — Clock-in Station dashboard card + attendance PDF fixes

- **Timestamp:** 2026-10-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** (1) The clock-in kiosk was only reachable from the login screen — add a
  **dashboard card** for it. (2) The generated attendance PDF showed **box/tofu
  characters** in the title and **wrapped column text** ("Wednesday").
- **Status:** Applied (frontend). `flutter analyze` (only 2 benign const infos);
  `flutter build web` ok.

## Changes
- **`screens/dashboard_screen.dart`:** new **"Clock-in Station"** tile
  (`Icons.fingerprint`) that opens the kiosk (`ClockKioskScreen`), shown to the
  clock-capable roles (Super Admin / Admin / IT / Area Manager / Store / Foodmall),
  alongside Clock In Staff and Attendance Register. (The login-screen
  "Clock-in station" link stays for the no-login station use.)
- **`screens/attendance_pdf.dart`:**
  - **Tofu fix:** the base PDF font (Helvetica) only renders ASCII, so the `–`
    (en-dash) and `•` (bullet) in the header came out as boxes. Added `_ascii()`
    folding typographic chars to ASCII and apply it to the header + every cell
    (name, payroll, roster, times).
  - **No-wrap columns:** widened the employee table (262 pt) and columns
    (Day 60, In/Out 46, Hrs 28), bumped the cell font to 8 pt, and set cells to
    `maxLines: 1, softWrap: false` so "Wednesday"/times stay on one line.

## Rollback
- Remove the kiosk tile and revert the PDF changes; delete this changelog.
