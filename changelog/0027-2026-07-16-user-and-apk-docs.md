# Changelog 0027 — User guide + APK build docs

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Documentation explaining every feature and every role, plus how to roll
  the app out as an Android APK.
- **Status:** Applied on disk (docs only).

## What changed
- `docs/USER_GUIDE.md` (new): plain-English guide — roles at a glance + per-role
  detail, core concepts, features by area (sign-in, dashboard, employees, brands/
  stores hub, users & roles, My Cluster, cross-store, staff page, notes + visibility,
  status feed, notifications, audit logs, settings), the automatic notification
  triggers, a who-can-see-what reference, and a glossary.
- `docs/BUILD_APK.md` (new): Android build guide — prerequisites/`flutter doctor`,
  choosing the correct `API_BASE_URL` (LAN IP / `10.0.2.2` / domain, not localhost),
  the cleartext-HTTP gotcha, build commands, install/distribute options, and the
  pre-production checklist (app id, icon, signing keystore, HTTPS, versioning).

## Files touched
- docs/USER_GUIDE.md — NEW
- docs/BUILD_APK.md — NEW

## Deployment
- Built: no. Deployed to production: no. (Documentation only.)

## Rollback
- Delete the two docs.
