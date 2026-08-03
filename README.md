# Staff Portal (staffmgmt)

Multi-tenant staff-management web + mobile app for a multi-brand restaurant /
hospitality group (Trinidad). **Backend:** FastAPI + SQLModel + PostgreSQL
(Docker). **Frontend:** Flutter — one codebase for **web and Android**. One
origin serves the UI and the API; it's published over a **Cloudflare tunnel**.

Owner: **Arif Asad Ali**.

> **Read `CLAUDE.md` first** — it holds the standing rules and conventions and
> takes precedence. Per-change detail is in `changelog/NNNN-*.md` (highest number
> = newest). This README is the **current-state overview + latest handoff**; the
> older `SESSION_HANDOFF.md` (through changelog 0029) is superseded here.

_Last updated: 2026-07-31 (AST)._

---

## Current status

- **Live:** https://gbgstaff.atmix.io (Cloudflare tunnel → `backend:8000`; single
  origin serves the Flutter web UI + the API).
- **Git:** branch `main`, tip **`68293b1`** pushed to
  `github.com/yaffirz/staffmgmt`. **Two changes are uncommitted** — changelog
  **0040** (in-app APK download) and **0041** (no-store cache fix) — held pending
  a one-time Cloudflare cache purge (see *Outstanding*).
- **Containers:** `backend`, `cloudflared`, `db` (healthy) all up.

## Roles

Super Admin · Admin · HR · Area Manager · IT · **Store** · **Foodmall**
(users may hold multiple roles; effective = primary + additional, carried in the
JWT). Access is enforced server-side.

## How to run / operate

All `docker compose` commands run from the **project root** (`C:\Projects\staffmgmt`).

```bash
# Backend + DB (API on :8000). Add --build after backend dep/Dockerfile changes.
docker compose up -d
# Publish the web UI (backend serves staff_frontend/build/web at "/"):
cd staff_frontend && flutter build web           # no --dart-define -> uses same origin
# Hot-reload web dev instead (separate origin):
flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8000
# DB shell:
docker compose exec db psql -U staffadmin -d staffmgmt -c "\dt"
# Publish to the Cloudflare tunnel (TUNNEL_TOKEN in .env):
docker compose --profile tunnel up -d
# Android APK:
cd staff_frontend && flutter build apk --release
scripts/publish-apk.sh            # copies the APK to ./public for in-app download
```

- **Backups need `docker compose build backend`** — the image now installs
  `postgresql-client` (pg_dump) + APScheduler.
- `.env` (gitignored) holds `TUNNEL_TOKEN` (for tunnel `a94a0059`, hostname
  `gbgstaff.atmix.io`), DB creds, `JWT_SECRET_KEY`, seed admin. `.env.example`
  is the template.
- New backend Python files auto-reload (`--reload`); new **Flutter** files need a
  full `flutter build web` (or a full `flutter run` restart), not hot reload.

## Feature set (per changelog)

Foundations (0001–0034, committed): auth/roles, employees CRUD + new-hire wizard,
brands→stores→positions hub, bulk CSV import, Users & Roles, Area Manager
clusters (move/request/cross-store), staff notes (per-note visibility), status
changes, notifications + bell, audit-log console, maintenance mode, announcements,
custom logo/branding, **single-origin serving + Cloudflare tunnel**.

**This session (0035–0041):**
- **0035 — Login marketing block:** admin-editable promo on login (text/image/
  video-embed), public `GET /api/v1/marketing`, Settings toggle.
- **0036 — Store & Foodmall roles:** store-level logins bound to one store
  (`store_users`), seeing only that store's staff restricted to **name + brand**
  via `GET /api/v1/store/summary`; can request staff (notifies Admins); blocked
  from full employee/cluster endpoints. A **foodmall** store (`is_foodmall`)
  carries multiple brands (`store_brands`); Foodmall accounts see staff grouped
  by brand.
- **0037 — Registration foundation:** public sign-up → email confirm → admin
  approval, in a separate `registration_requests` table. **Email sending is a
  stub** (`core/email.py` logs the link) until the domain is set up.
  `registration_enabled` toggle (default off).
- **0038 — Admin hub + activity console:** config tiles moved behind one **Admin**
  tile (`admin_hub_screen`); a read-only, terminal-styled **Activity Console**
  streams the audit log (auto-refresh; never a shell). Shared `module_card.dart`.
- **0039 — Database backups:** Super-Admin `pg_dump` — "Back up now" with animated
  elapsed/indeterminate progress, host-mounted `./backups` (gitignored),
  Super-Admin **download** (audited) + delete, and **scheduled** daily/weekly with
  retention (in-app APScheduler). `core/backup.py`, `core/scheduler.py`,
  `routes/backups.py`, `Backups` table.
- **0040 — In-app APK download (login-gated, UNCOMMITTED):** signed-in users get a
  "Get the Android app" card on the dashboard (web only) → downloads the latest
  APK served read-only from `./public`. `GET /api/v1/app/{info,download}` (auth);
  `app_download_enabled` toggle.
- **0041 — No-store web shell (UNCOMMITTED):** backend sends `Cache-Control:
  no-store` on `.html/.js/.json` so Cloudflare stops serving stale builds.

## Problems encountered & solutions

- **Cloudflare tunnel 502s (multi-part).** (1) `TUNNEL_TOKEN` was empty →
  `cloudflared` crash-looped ("requires the ID of the tunnel") → put the token in
  `.env`. (2) A hand-run `cloudflared` (`docker run`) sat on the **default bridge**
  network and couldn't resolve `backend` → run the connector via the **compose
  service** (on `staffmgmt_default`, service `http://backend:8000`) and remove the
  stray one. (3) The public hostname must be owned by the **same tunnel**
  (`a94a0059`) our connector runs. Verified `total_requests`/logs to prove traffic
  arrival. Now returns 200.
- **Orphaned Foodmall account.** `create_user` committed the row *before*
  validating the store, so a bad store left an account with no link. **Fixed** by
  validating the store (exists, in-tenant, foodmall for Foodmall) **before**
  creating the row.
- **APK build vs `dart:html`.** Web-only code (bulk CSV I/O, marketing embed,
  backup/APK download) is behind **conditional imports**, so the Android release
  AOT build uses native stubs. APKs build clean (~52 MB).
- **Stale deploys via Cloudflare cache.** Flutter's `main.dart.js` has a fixed
  filename → Cloudflare cached it (~4h) and served old builds *even in incognito*
  (edge cache, not the browser). **Fixed** with `no-store` on the app shell (0041);
  the already-cached copy needs a **one-time Cloudflare purge** to clear.
- **Visual QA limited.** The in-app preview browser pane wasn't compositing this
  session (screenshots time out), so features were verified via **curl/API +
  `flutter analyze` + release builds** rather than screenshots. The live tunnel is
  the place to eyeball UI.
- **Presentation tooling.** `pptxgenjs` + `defusedxml/lxml/python-pptx` weren't
  preinstalled (installed on demand); no LibreOffice/Poppler on the box, so slide
  images couldn't be rendered for QA — the deck (`docs/StaffPortal_Overview.pptx`)
  was validated structurally instead.

## Outstanding / next steps

1. **Cloudflare purge (owner action):** dashboard → `atmix.io` → Caching →
   Configuration → **Purge Everything** (one-time) to clear the stale
   `main.dart.js`. After that the "Get the Android app" card appears and future
   deploys are instant (thanks to 0041).
2. **Commit + push 0040 + 0041** once the purge is confirmed (suggest one commit
   for the APK-download feature + the cache fix, or two).
3. **Security before real staff use:** rotate the admin password off
   `ChangeMe123!` (Users & Roles) and set a strong `JWT_SECRET_KEY`
   (`openssl rand -hex 32`); both are still on test values. Wire real SMTP into
   `core/email.py` once the sending domain (SPF/DKIM) is configured to switch
   registration emails from stub to live.
4. **Dev-data cleanup (optional):** a demo **"Trincity Foodcourt"** foodmall store
   (brands Pizza Boys + Churchs + Rituals) exists; the **login marketing block**
   may still show placeholder "Now hiring…" text — disable/edit in
   **Settings → Login marketing block** if unwanted. Current toggles:
   `registration_enabled` off, `backup_schedule` off, `app_download_enabled` on.

## Test accounts (dev DB) — password `ChangeMe123!` unless noted

| Username | Role(s) | Notes |
|---|---|---|
| `superadmin` | Super Admin | Seeded. |
| `admin_test` | Admin | |
| `Davindra` | Admin | Pre-existing; **password unknown**. |
| `am_pizza` | Area Manager | Covers Pizza Boys. |
| `Nadiya` | Area Manager | Covers Rituals; **password unknown**. |
| `hr_test` | HR + IT | Multi-role. |
| `it_test` | IT | |

(Session test users `store_test` / `foodmall_test` / `newbie` were created and
then **deleted** — recreate via Users & Roles / Registrations to test those flows.)

## Conventions (recap — see CLAUDE.md for the authoritative list)

- **Every committed change gets a new `changelog/NNNN-YYYY-MM-DD-title.md`** —
  never overwrite; review the latest before changing anything.
- Toggleable features get an admin control (Settings). Admin mini-console exists
  (Audit Logs + the new Activity Console).
- Dates display **MM/DD/YYYY**, wire **YYYY-MM-DD**. `tenant_id` from the JWT
  (Phase 1 = 1). Passwords bcrypt. Footer "Created by Arif Asad Ali".
- Non-destructive, idempotent DB migrations in `core/database.py::_run_migrations`
  (`ADD COLUMN IF NOT EXISTS`, drop/recreate CHECK); new tables via `create_all`.
  Never `docker compose down -v` (wipes data).
- Verify before delivering: backend `python -m compileall`; frontend
  `flutter analyze`.

## Repo map (key paths)

```
docker-compose.yml            # db + backend (+ cloudflared profile); web/backups/public mounts
.env / .env.example           # secrets (gitignored) / template
backend/app/
  main.py                     # app, routers, static web mount (no-store), scheduler start
  core/{backup,scheduler,email,app_settings,database,security,config}.py
  api/routes/                 # auth, employees, users, cluster, store_portal, registration,
                              #   backups, app_dist, marketing, maintenance, announcements, ...
  models/models.py            # full schema
staff_frontend/lib/           # Flutter (screens/, widgets/, services/, models/, state/)
changelog/                    # 0001..0041 per-change detail
docs/                         # USER_GUIDE, BUILD_APK, CLOUDFLARE_TUNNEL, StaffPortal_Overview.pptx
scripts/publish-apk.sh        # publish the built APK to ./public
```
