# Changelog 0085 — Hide clock-in staff in All-employees + store clock-only dashboard

- **Timestamp:** 2026-10-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** (1) On the All-employees page, hide **clock-in (non-Oracle) employees**
  by default, with a toggle to show them; an employee who belongs to **both** a
  non-Oracle brand and a regular brand stays visible. (2) Store-level accounts get
  a **clock-only dashboard** (just the three clock tiles, no employee list).
- **Status:** Applied (backend + frontend). `clock_in_only` verified via API;
  `flutter analyze` (only pre-existing infos); `flutter build web` ok.

## All-employees: hide clock-in staff
- **Backend:** `EmployeeRead.clock_in_only` (computed in the list endpoint): true
  when the employee is **non-Oracle** (brand flag or override) **and** every brand
  they belong to — their effective brand plus any additional store's brand — is
  non-Oracle. If they also belong to a regular brand, it's false (always shown).
- **Frontend:** `Employee.clockInOnly`; the list hides `clockInOnly` employees by
  default. An app-bar **toggle** (shown only when such staff exist) flips
  Hide/Show — `Icons.visibility_off` ↔ `visibility`. Applies to table + card
  views (filter in the shared data source).

## Store-level clock-only dashboard
- **`dashboard_screen.dart`:** the **Store** and **Foodmall** roles now return no
  base modules, so they see **only** the three injected clock tiles — **Clock-in
  Station**, **Clock In Staff**, **Attendance Register** — and no employee list.
  (Admins/HR/IT keep the full dashboard; Area Managers keep their cluster tools +
  the clock tiles.)

## Also
- Removed a stray embedded **NUL byte** in `employees_list_screen.dart` (a sentinel
  string had `'\0__all__'`; now `'__all__'`) so the file is clean UTF-8/editable.

## Verification
- API: `clock_in_only` = true for a Heroes (non-Oracle brand) employee; false for a
  Fresh-To-Go employee who is non-Oracle only via override (their brand is regular).

## Rollback
- Remove the `clock_in_only` field + computation, the list toggle, and restore the
  Store/Foodmall `My Store`/`My Foodmall` modules; delete this changelog.
