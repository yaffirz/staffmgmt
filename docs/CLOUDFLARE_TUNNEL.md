# Publishing the app via a Cloudflare Tunnel

This serves the **whole app on one hostname**: the backend (`:8000`) serves both
the API and the built Flutter web UI, and a `cloudflared` container publishes it
through your Cloudflare domain — no inbound ports opened on your machine/router.

```
Browser ──HTTPS──> Cloudflare edge ──tunnel──> cloudflared ──> backend:8000
                                                                 ├─ /            → Flutter web UI
                                                                 ├─ /api/v1/...  → FastAPI
                                                                 └─ /health,/docs
```

## Prerequisites
- A **Cloudflare account** with your **domain added as a zone** (its nameservers
  point to Cloudflare). If the domain isn't on Cloudflare yet, do that first.
- Docker + Docker Compose (already used by this project).

## One-time setup

### 1. Build the web UI
The backend serves `staff_frontend/build/web` (bind-mounted read-only). Build it
**without** an `API_BASE_URL` define so the app talks to its own origin:
```
cd staff_frontend
flutter build web
```
Re-run this whenever the frontend changes.

### 2. Create the tunnel and get its token
In **Cloudflare Zero Trust → Networks → Tunnels → Create a tunnel → Cloudflared**:
- Name it (e.g. `staffmgmt`), choose the **Docker** connector, and copy the
  **token** it shows (a long string).
- Add a **Public Hostname**:
  - Subdomain/hostname: e.g. `staff.yourdomain.com`
  - Service: **HTTP** → `backend:8000`  *(the compose service name + port)*

### 3. Put the token in `.env`
In the repo-root `.env` (gitignored):
```
TUNNEL_TOKEN=eyJ...your-token...
```

### 4. Harden before going public
- **Change the admin password.** Set `SEED_ADMIN_PASSWORD` in `.env` to a strong
  value *before first run*, or log in and change it via **Users & Roles**. The
  default `ChangeMe123!` is well-known.
- Set a strong `JWT_SECRET_KEY` (e.g. `openssl rand -hex 32`).

### 5. Start everything (including the tunnel)
```
docker compose --profile tunnel up -d
```
- Plain `docker compose up -d` runs the app **without** the tunnel (the
  `cloudflared` service is gated behind the `tunnel` profile).
- Your app is now live at `https://staff.yourdomain.com`. Cloudflare terminates
  TLS at the edge, so the app is HTTPS even though the backend speaks HTTP
  internally.

## Notes
- **One origin, no CORS:** the web UI is same-origin with the API, so no CORS
  config is needed. On web the app auto-uses its own origin (no "connect to
  server" prompt).
- **Android APK:** point the app's server field at `https://staff.yourdomain.com`.
  Because it's now HTTPS, you can drop `usesCleartextTraffic` from the release
  manifest (see `docs/BUILD_APK.md`).
- **Port:** the tunnel targets the existing backend port `8000` (internal to the
  compose network) — no host ports need to be exposed to the internet.
- **Access control (optional):** you can put Cloudflare Access in front of the
  hostname for an extra auth layer, or restrict by country/WAF in the dashboard.
- **Updating the UI:** re-run `flutter build web`; the backend serves the new
  files immediately (bind-mounted). No rebuild of the backend image needed.
