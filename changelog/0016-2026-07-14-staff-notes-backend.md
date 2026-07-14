# Changelog 0016 — Staff notes backend (per-note visibility) + migration

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Backend for an individual staff page with notes. Default visibility
  author + Super Admin; author can share a note by role and/or brand; Super Admin
  overrides. Toggleable feature.
- **Status:** Applied + running on the dev backend (migration ran on restart);
  verified via curl. `python -m compileall` clean.

## Schema change (non-destructive migration)
- `StaffNotes` gained `visibility_roles` (JSONB, default `[]`) and
  `visibility_brand_ids` (JSONB, default `[]`). Empty both = private.
- New `_run_migrations()` in `core/database.py` runs
  `ALTER TABLE staff_notes ADD COLUMN IF NOT EXISTS ...` after `create_all`
  (idempotent). Confirmed both columns present as jsonb.

## Visibility rule
A user sees a note if they are the **author**, a **Super Admin**, their **role** is
in `visibility_roles`, or they are an **Area Manager of a brand** in
`visibility_brand_ids`. (Admin/HR do NOT see private notes — only Super Admin does.)

## Endpoints (roles: Area Manager / HR / Admin / Super Admin)
- `GET /api/v1/staff/{id}` — staff-page header (name, payroll, store, brand,
  position); Area Managers scoped to their cluster (else 404).
- `GET /api/v1/staff/{id}/notes` — notes visible to the caller, newest first.
- `POST /api/v1/staff/{id}/notes` — create; author = caller; visibility from body;
  gated by `staff_notes_enabled`.
- `PATCH /api/v1/staff/notes/{note_id}` / `DELETE .../{note_id}` — author or
  Super Admin.
- `GET /api/v1/auth/me/brands` — the caller's own brands (defaults the brand
  picker); empty for non-AMs.
- New setting `staff_notes_enabled` (default true), settable via the settings API.

## Files touched
- backend/app/models/models.py — StaffNotes visibility columns (+ text import)
- backend/app/core/database.py — idempotent migration runner
- backend/app/core/app_settings.py — staff_notes_enabled default
- backend/app/api/routes/auth.py — GET /me/brands
- backend/app/schemas/notes.py — NEW
- backend/app/api/routes/notes.py — NEW (staff page + notes CRUD + visibility)
- backend/app/main.py — register notes router

## Verification (curl)
- Migration: both jsonb columns present; `staff_notes_enabled=true` seeded.
- am_pizza: /me/brands = [Pizza Boys]; GET /staff/3 = 200 (in cluster);
  GET /staff/1 = 404 (out of cluster). Created private/brand/role notes with
  correct labels; author sees all own.
- Super Admin sees all 3 notes; new HR user (hr_test) sees ONLY the HR-shared note
  (not private, not brand). Toggle off → POST note = 403; restored to true.

## Test data left on dev DB
- 3 notes on employee 3; a `hr_test` HR user (kept for visibility testing).

## Deployment
- Built: no (volume + reload). Backend restarted; migration applied. Frontend TBD.
- Deployed to production: no

## Rollback
- Revert the code edits + remove notes route/schema. The two staff_notes columns
  can be left (harmless) or dropped manually.
