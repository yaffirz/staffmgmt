# Changelog 0020 — IT role + multi-role users

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Add an IT role and allow users to hold multiple roles (assignable only
  by a Super Admin). Foundation that unblocks the 5 notification triggers. IT is
  "admin-lite" (view/manage staff + notes + notifications).
- **Status:** Backend applied + running + verified via curl; frontend applied,
  `flutter analyze` clean. Pending a frontend hot restart to load.

## Model (migration-friendly)
- `users.role` stays the **primary** role; its CHECK constraint widened to include
  `IT` (idempotent drop+recreate migration).
- New `user_roles(user_id, role)` junction for **additional** roles. Effective
  roles = {primary} ∪ {additional}.
- `ALLOWED_ROLES` gains `IT`.

## Auth (backward compatible)
- JWT now carries a `roles` claim (effective set); `role` kept. `CurrentUser` gains
  `roles` + a `has_role(*any)` helper. Old tokens fall back to `[role]`.
- `require_roles(...)` checks **intersection** with effective roles (all gating
  upgrades automatically).
- Explicit `role == / in` checks in notes + notifications switched to effective
  roles (`has_role`, union in `_visible_roles`).
- Login computes effective roles (`effective_roles()`), mints them into the token,
  and returns them.

## Users API (multi-role, Super-Admin-gated)
- `UserCreate`/`UserUpdate` accept `additional_roles`; only a **Super Admin** may
  set them (else 403). `UserRead` returns `roles` + `additional_roles`.
- `user_roles` cleaned up on user delete.
- IT added to admin-lite role sets: employees `WRITE_ROLES`, staff `STAFF_ROLES`,
  store drilldown `VIEW_ROLES` (NOT users/settings/org/delete).

## Frontend
- `AuthUser` / `UserAccount` gain `roles` (+ `additionalRoles`); `hasRole` helper.
- Dashboard builds modules from the **union** of effective roles (deduped by
  title); added an **IT** module set (Employees + Staff Notes). Welcome line lists
  all roles.
- Users & Roles: `IT` in the role dropdown + color; a Super-Admin-only "Additional
  roles" chip picker; cards show "Also: <roles>".

## Files touched
- backend: models.py, core/database.py, core/security.py, schemas/auth.py,
  api/deps.py, api/routes/auth.py, api/routes/notes.py, api/routes/notifications.py,
  api/routes/users.py, schemas/user.py, api/routes/employees.py, api/routes/stores.py
- frontend: models/auth_user.dart, models/user_account.dart,
  services/staff_service.dart, screens/dashboard_screen.dart, screens/users_screen.dart

## Verification (curl, backend)
- Migration: ck_users_role includes IT; user_roles table created.
- Tokens carry effective roles; am_pizza + additional IT → roles ['Area Manager','IT'].
- IT user created (role IT); hr_test granted additional IT → ['HR','IT']; an Admin
  is BLOCKED from assigning additional roles (403). IT can GET /employees (200) but
  not /settings (403).
- Test users left on dev DB: it_test (IT), admin_test (Admin), hr_test (now HR+IT).

## Deployment
- Built: no. Backend restarted (migration ran). Frontend hot restart required
  (existing-file edits only — no new files).
- Deployed to production: no

## Rollback
- Revert the listed edits; `user_roles` table + the widened constraint can remain.
