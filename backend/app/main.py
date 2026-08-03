import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlmodel import Session

from app.api.routes import (
    announcements,
    app_dist,
    audit,
    auth,
    backups,
    cluster,
    employees,
    form_config,
    lookups,
    maintenance,
    marketing,
    notes,
    notifications,
    registration,
    settings as settings_routes,
    status as status_routes,
    store_portal,
    stores,
    users,
)
from app.core import scheduler
from app.core.database import engine, init_db
from app.seed import seed_initial_data


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Runs once on startup: create tables, seed a Super Admin, start the
    # backup scheduler.
    init_db()
    with Session(engine) as session:
        seed_initial_data(session)
    scheduler.start()
    yield


app = FastAPI(
    title="Staff Management API",
    version="0.1.0",
    description="Phase 1 backend: auth + schema foundation.",
    lifespan=lifespan,
)

# Dev-friendly CORS so the Flutter web portal and mobile emulators can call in.
# Tighten allow_origins to your real domains before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(employees.router)
app.include_router(lookups.router)
app.include_router(form_config.router)
app.include_router(users.router)
app.include_router(cluster.router)
app.include_router(settings_routes.router)
app.include_router(notifications.router)
app.include_router(stores.router)
app.include_router(notes.router)
app.include_router(status_routes.router)
app.include_router(audit.router)
app.include_router(maintenance.router)
app.include_router(announcements.router)
app.include_router(marketing.router)
app.include_router(store_portal.router)
app.include_router(registration.router)
app.include_router(backups.router)
app.include_router(app_dist.router)


@app.get("/health", tags=["meta"])
def health():
    return {"status": "ok"}


# --- Static frontend (optional) ---------------------------------------------
# When a built Flutter web bundle is present (bind-mounted in via docker-compose,
# or copied in), serve it at the root so ONE origin serves both the UI and the
# API — ideal behind a single Cloudflare tunnel hostname (no CORS, one link).
# Mounted LAST so it never shadows /health, /docs, or the /api/v1 routes.
# Absent in pure-API/dev setups, so this is a no-op there.


class _AppStatic(StaticFiles):
    """Serve the built web app, but mark the mutable app-shell files
    (index.html + the Dart/JS/JSON that change every `flutter build web`) as
    no-store, so a CDN (Cloudflare) never serves a stale build after a deploy.
    Binary assets (wasm, fonts, images) keep default caching."""

    def file_response(self, full_path, stat_result, scope, status_code=200):
        resp = super().file_response(full_path, stat_result, scope, status_code)
        if str(full_path).endswith((".html", ".js", ".json")):
            resp.headers["Cache-Control"] = "no-store"
        return resp


WEB_DIR = os.getenv("WEB_DIR", "/code/web")
if os.path.isfile(os.path.join(WEB_DIR, "index.html")):
    app.mount("/", _AppStatic(directory=WEB_DIR, html=True), name="web")
