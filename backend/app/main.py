import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlmodel import Session

from app.api.routes import (
    announcements,
    audit,
    auth,
    cluster,
    employees,
    form_config,
    lookups,
    maintenance,
    notes,
    notifications,
    settings as settings_routes,
    status as status_routes,
    stores,
    users,
)
from app.core.database import engine, init_db
from app.seed import seed_initial_data


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Runs once on startup: create tables, then seed a Super Admin.
    init_db()
    with Session(engine) as session:
        seed_initial_data(session)
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


@app.get("/health", tags=["meta"])
def health():
    return {"status": "ok"}


# --- Static frontend (optional) ---------------------------------------------
# When a built Flutter web bundle is present (bind-mounted in via docker-compose,
# or copied in), serve it at the root so ONE origin serves both the UI and the
# API — ideal behind a single Cloudflare tunnel hostname (no CORS, one link).
# Mounted LAST so it never shadows /health, /docs, or the /api/v1 routes.
# Absent in pure-API/dev setups, so this is a no-op there.
WEB_DIR = os.getenv("WEB_DIR", "/code/web")
if os.path.isfile(os.path.join(WEB_DIR, "index.html")):
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")
