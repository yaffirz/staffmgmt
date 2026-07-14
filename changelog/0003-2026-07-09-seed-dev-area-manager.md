# Changelog 0003 — Dev seed: testable Area Manager for Phase 2

**Date:** 2026-07-09 (AST, UTC-4)
**Requested by:** Arif
**Type:** Backend code change (seed). Status: **Applied on disk — NOT yet deployed** (takes effect on next backend restart).

## Why
Phase 2 (My Cluster + Move/Request) is about to be built, but the flows are
untestable end-to-end with the current data:
- The only existing Area Manager, **Nadiya** (user_id 3, manager_id 2), is scoped
  to brand **Rituals Coffee House** (brand 3), which has a single store (Chaguanas
  #7) and **zero employees** — so her cluster is empty and can't exercise Move
  (needs ≥2 in-scope stores + a primary-here staffer). Her password is also unknown.
- Brand **Pizza Boys** (brand 1) already has two stores (San Fernando #2,
  Chaguanas #3) and two employees whose primary stores are those — a ready-made
  testable cluster with **no AM assigned**.

So this seeds one known-credentials Area Manager over Pizza Boys. It fabricates
**no** employees — it reuses the brand's existing stores/staff.

## What changed
- `config.py`: added dev-AM settings — `SEED_DEV_AREA_MANAGER` (bool, default True),
  `SEED_AM_USERNAME` (`am_pizza`), `SEED_AM_PASSWORD` (`ChangeMe123!`),
  `SEED_AM_BRAND_NAME` (`Pizza Boys`). Set `SEED_DEV_AREA_MANAGER=false` in real
  deployments to skip.
- `seed.py`: imported `AreaManagers`, `AreaManagerBrands`; added idempotent
  `_seed_dev_area_manager(session, tenant)`, called from `seed_initial_data`. It
  ensures (a) an Area Manager user, (b) an `area_managers` row, (c) an
  `area_manager_brands` link to Pizza Boys — each created only if missing. If the
  brand doesn't exist in the tenant, it no-ops.

## Files touched
- backend/app/core/config.py — new SEED_DEV_* settings
- backend/app/seed.py — imports + `_seed_dev_area_manager` step

## Verification
- `python -m compileall app/seed.py app/core/config.py` → clean.
- Seed logic runs on backend startup (idempotent). NOT yet run — backend not
  rebuilt/restarted (human controls the deploy trigger).
- After next restart, verify:
  `docker compose exec db psql -U staffadmin -d staffmgmt -c "select u.username, u.role, am.manager_name, b.brand_name from users u join area_managers am on am.user_id=u.user_id join area_manager_brands amb on amb.manager_id=am.manager_id join brands b on b.brand_id=amb.brand_id where u.username='am_pizza';"`

## Deployment
- Built: no
- Deployed to production: no
- Note: takes effect only after `docker compose up -d --build backend` (human-triggered).

## Rollback
- Revert the two edits (git). No DB rows are written until the backend restarts;
  if it has restarted, delete the seeded `am_pizza` user + its `area_managers` /
  `area_manager_brands` rows.
