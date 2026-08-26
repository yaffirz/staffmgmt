# Changelog 0057 — Fix 500 deleting a user with notification references

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** surfaced while testing (deleting a test user)
- **Task:** Deleting a user 500'd with a `notification_reads_user_id_fkey`
  foreign-key violation once that user had read/dismissed anything (e.g. tapping
  "Got it" on an announcement creates a `notification_reads` row).
- **Status:** Fixed and verified (delete now returns 204). `compileall` clean;
  backend hot-reloaded.

## Fix (`api/routes/users.py`, `delete_user`)
Before deleting the user, also remove the rows that FK-reference them and were
not being cleaned up:
- `notification_reads` for that user (read/dismissed markers), and
- `notifications` addressed personally to them (`recipient_user_id`).

(Role links, Area-Manager scope and Store/Foodmall links were already handled.)

## Known limitation
Deleting a user who authored **staff notes** or processed **status changes**
still leaves `staff_notes.author_user_id` / `staff_status_log.processed_by`
references, which would block the delete — that's a separate policy decision
(keep vs reassign history) and is out of scope here.

## Rollback
- Revert the edit.
