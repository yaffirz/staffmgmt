# Changelog 0019 — Fix: all-notes feed failed to parse (missing fields)

- **Timestamp:** 2026-07-14 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** The "Staff Notes" feed showed "Could not load notes." in the browser.
- **Status:** Backend fix applied + restarted; verified in-browser. Frontend
  defensive edit applied (not required once backend is fixed).

## Root cause
The feed request returned 200, so it was a client-side parse error. The frontend
reuses `StaffNote.fromJson`, which reads `j['author_user_id'] as int`, but the
backend `NoteFeedItem` did not include `author_user_id` (nor the visibility
arrays) — so the cast hit null and threw, and `_load`'s catch surfaced the generic
"Could not load notes."

## Fix
- Backend `NoteFeedItem` + the feed endpoint now include `author_user_id`,
  `visibility_roles`, and `visibility_brand_ids` (matching the per-employee notes
  shape the client expects).
- `StaffNote.fromJson` now parses `author_user_id` defensively
  (`(j['author_user_id'] as int?) ?? 0`).

## Files touched
- backend/app/schemas/notes.py — NoteFeedItem extra fields
- backend/app/api/routes/notes.py — populate the extra fields
- staff_frontend/lib/models/staff_note.dart — defensive author_user_id parse

## Verification (in-browser, as hr_test)
- Feed keys now include author_user_id + visibility arrays.
- Staff Notes tile → feed lists exactly the one HR-shared note on "1234" (HR does
  NOT see the private/brand notes). Row → staff page.
- Staff page: header correct; Add note dialog (Private/Roles/Brands) works; created
  a Private note (author hr_test, lock chip, delete affordance); deleted it via the
  confirm dialog.

## Deployment
- Built: no. Backend restarted (volume+reload). Frontend defensive edit loads on
  next frontend restart (not required for the fix).
- Deployed to production: no

## Rollback
- Revert the three edits.
