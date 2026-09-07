# Changelog 0063 — Status Changes quick-action buttons (search staff → act)

- **Timestamp:** 2026-09-07 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** On the Status Changes page (currently a read-only feed full of test
  data), add buttons so HR / Admin / Super Admin can search for a staffer and
  promote / demote / terminate / reactivate them without hunting through the
  Employees list.
- **Status:** Applied (frontend only; no schema/API change). Verified in-browser.

## Background — how status changes already work
The promote / demote / terminate / reactivate logic already existed and was
verified: `POST /api/v1/staff/{id}/status` (role-gated to **Super Admin, Admin,
HR** — `STATUS_ROLES` in `backend/app/api/routes/status.py`) updates the
employee, appends to `staff_status_log`, notifies the IT role, and writes an
audit row. It was reachable only from each employee's **detail page** (Promote /
Demote / Terminate / Reactivate buttons). The Status Changes tile was a
**read-only feed** of those events. This change adds a fast entry point; it does
**not** add a new way to mutate data — it reuses the exact same, already-verified
detail-page actions.

## What changed (design chosen with Arif)
Flow = **search → open that staffer's profile with the action pre-armed**
(single source of truth; no duplicated action UI). Buttons = **four separate**
(Promote, Demote, Terminate, Reactivate).

- **`staff_frontend/lib/screens/status_feed_screen.dart`**
  - A **"Record a status change"** bar (four `OutlinedButton`s: Promote ↑,
    Demote ↓, Terminate, Reactivate), shown only to Super Admin / Admin / HR
    (effective roles) — matching the backend `STATUS_ROLES`.
  - Each button opens a **`_StaffSearchDialog`** — a modal name search over all
    staff (`StaffService.listEmployees()`, allowed for these roles), loaded once
    and **cached** on the screen, filtered client-side (case-insensitive
    substring on name); each row shows name · position · brand · store.
  - Picking a staffer pushes `EmployeeDetailScreen(initialAction: <ACTION>)`;
    on return the feed reloads so the new event shows.
  - The empty-feed message now sits **below** the action bar instead of
    replacing the whole body.
- **`staff_frontend/lib/screens/employee_detail_screen.dart`**
  - New optional `initialAction` param ('PROMOTION' | 'DEMOTION' |
    'TERMINATION' | 'REACTIVATION'). After the first successful load,
    `_maybeRunInitialAction()` fires the matching existing handler **once**
    (post-frame): promote/demote → the brand-scoped position picker; terminate /
    reactivate → the reason dialog. Guards no-op sensibly (e.g. Terminate on an
    already-terminated staffer just shows a snackbar), and the manual buttons on
    the page are unchanged.

## Verification
- `flutter analyze` on both files — no new issues (only pre-existing
  `use_build_context_synchronously` infos in the note create/delete paths, and a
  `withOpacity` deprecation matching the codebase's existing style).
- `flutter build web` — succeeds; icons used are non-outlined (`person_off`,
  `arrow_upward`, `arrow_downward`, `restart_alt`, `search`, `person`) to avoid
  the tree-shaker drop noted in 0053.
- **In-browser (localhost:8000, superadmin):** the four buttons render; the
  search dialog loads real GBG staff and filters live; **Terminate → search →
  pick** auto-opened the "Terminate <name>?" reason dialog; **Promote → search →
  pick** auto-opened the position picker populated with the staffer's
  brand-scoped positions. Cancelled every dialog — **no real staff data was
  changed**.

## Rollback
- Revert the edits to `status_feed_screen.dart` and `employee_detail_screen.dart`
  (drop the `initialAction` param); delete this changelog file.
