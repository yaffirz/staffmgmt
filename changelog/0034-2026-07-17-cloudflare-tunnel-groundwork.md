# Changelog 0034 — Cloudflare tunnel groundwork (single-origin serving)

- **Timestamp:** 2026-07-17 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Prepare the app to be published via a Cloudflare tunnel in Docker,
  reusing the existing backend port. Groundwork only — the live tunnel needs the
  owner's Cloudflare account, hostname, and token.
- **Status:** Applied; verified end-to-end that the backend serves the UI + API
  on one origin (:8000) and the web app auto-uses that origin.

## Architecture
One hostname serves everything: the backend (`:8000`) serves both the API and the
built Flutter web UI; a profile-gated `cloudflared` container publishes it.
```
Browser ─HTTPS→ Cloudflare edge ─tunnel→ cloudflared → backend:8000
                                                        ├ /           Flutter web UI
                                                        └ /api/v1,/health,/docs
```

## Backend
- `app/main.py`: after all routers, mount `StaticFiles(WEB_DIR, html=True)` at `/`
  **only if** `WEB_DIR/index.html` exists (env `WEB_DIR`, default `/code/web`).
  Mounted last, so it never shadows `/health`, `/docs`, or `/api/v1/*`. No-op in
  pure-API/dev setups.

## Docker
- `docker-compose.yml`: backend gains `WEB_DIR=/code/web` and a read-only bind
  mount `./staff_frontend/build/web:/code/web:ro`. New **`cloudflared`** service
  (`cloudflare/cloudflared`, `tunnel run`, `TUNNEL_TOKEN` from `.env`) gated behind
  the **`tunnel` profile** — plain `docker compose up -d` runs without it;
  `docker compose --profile tunnel up -d` includes it.

## Frontend
- `config/app_config.dart`: `apiBaseUrl` is now resolved — `--dart-define`
  override wins (dev/CI); otherwise on **web** it uses the page's own origin
  (`Uri.base.origin`); native falls back to localhost (the setup screen normally
  supplies the URL).
- `state/server_provider.dart`: on web with no stored server, auto-configure to
  the current origin and skip the "connect to your server" step. Native
  unchanged (still shows the setup screen — type the tunnel URL there).

## Docs / config
- `docs/CLOUDFLARE_TUNNEL.md` (new): full setup — build web, create the tunnel +
  token, route hostname → `backend:8000`, harden (admin password, JWT secret),
  `docker compose --profile tunnel up -d`.
- `.env.example`: documented `TUNNEL_TOKEN` + a warning to change the default
  admin password before public exposure.

## Verification
- `docker compose up -d` (recreated backend); `flutter build web`:
  - `GET :8000/` → Flutter UI (`<title>Staff Portal</title>`).
  - `GET :8000/api/v1/maintenance/status`, `/health`, `/favicon.svg`,
    `/main.dart.js` → all 200 (API not shadowed).
  - Browser at `:8000` skips the connect step, logs in same-origin, reaches the
    dashboard.

## Still needed from the owner (to go live)
- Cloudflare zone (domain on Cloudflare), a **public hostname**, and a
  **`TUNNEL_TOKEN`** in `.env` with the dashboard route → `http://backend:8000`.
- Change the seeded admin password off the default.

## Deployment
- Built: web bundle + backend recreated locally. Tunnel: not started (no token).
  Prod: no.

## Rollback
- Revert the edits; remove the `cloudflared` service, the web bind mount/`WEB_DIR`,
  and the static mount. Frontend resolver/provider changes are self-contained.
