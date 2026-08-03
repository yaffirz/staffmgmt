# Changelog 0042 — README rewritten as current-state handoff

- **Timestamp:** 2026-07-31 (AST, UTC-4)
- **Requested by:** Arif (before migrating to a new chat)
- **Task:** Bring the README up to date so a fresh session can continue seamlessly
  — everything covered recently, problems + solutions, and where things stand,
  without disturbing the operating rules in CLAUDE.md.
- **Status:** Applied (docs only).

## What changed
- `README.md` fully rewritten (it was still the original "Phase 1 backend" doc).
  Now covers: what the platform is + stack/architecture; current status (live at
  gbgstaff.atmix.io, git tip, uncommitted 0040/0041); how to run/operate
  (compose, web build, tunnel, APK publish); the feature set by changelog
  (0035–0041 this session); a **Problems encountered & solutions** section
  (Cloudflare tunnel 502s, orphaned Foodmall account, APK/`dart:html` conditional
  imports, stale Cloudflare cache → no-store, preview-pane/QA limits, pptx
  tooling); **Outstanding / next steps** (Cloudflare purge, commit 0040/0041,
  security rotation, dev-data cleanup); test accounts; and a conventions recap
  that defers to CLAUDE.md as authoritative.
- Points to `CLAUDE.md` (rules), `changelog/*` (detail) and notes it supersedes
  the older `SESSION_HANDOFF.md` for current state.

## Files touched
- README.md (rewritten)

## Deployment
- Docs only. Not committed yet (held with the 0040/0041 batch).

## Rollback
- Restore the previous README.md from git history.
