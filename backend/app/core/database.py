from collections.abc import Generator

from sqlalchemy import text
from sqlmodel import Session, SQLModel, create_engine

from app.core.config import settings

# pool_pre_ping avoids "server closed the connection" after idle periods.
engine = create_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True)

# Non-destructive, idempotent column additions for tables that already exist
# (create_all only creates missing tables, never alters existing ones).
_MIGRATIONS = [
    "ALTER TABLE staff_notes ADD COLUMN IF NOT EXISTS "
    "visibility_roles JSONB NOT NULL DEFAULT '[]'::jsonb",
    "ALTER TABLE staff_notes ADD COLUMN IF NOT EXISTS "
    "visibility_brand_ids JSONB NOT NULL DEFAULT '[]'::jsonb",
    # Widen the users.role check to include 'IT' + store-level roles. Drop+recreate
    # so it's idempotent (Postgres has no ADD CONSTRAINT IF NOT EXISTS).
    "ALTER TABLE users DROP CONSTRAINT IF EXISTS ck_users_role",
    "ALTER TABLE users ADD CONSTRAINT ck_users_role "
    "CHECK (role IN ('Super Admin', 'Admin', 'HR', 'Area Manager', 'IT', "
    "'Store', 'Foodmall'))",
    # Employment status for termination/reactivation.
    "ALTER TABLE employees ADD COLUMN IF NOT EXISTS "
    "employment_status VARCHAR NOT NULL DEFAULT 'active'",
    # Foodmall flag on stores (a foodmall carries multiple brands).
    "ALTER TABLE stores ADD COLUMN IF NOT EXISTS "
    "is_foodmall BOOLEAN NOT NULL DEFAULT false",
    # Universal positions: allow positions.brand_id to be NULL (NULL = a role
    # available to all brands, minus any in position_brand_optouts).
    "ALTER TABLE positions ALTER COLUMN brand_id DROP NOT NULL",
    # Provenance / review-completion timestamps on employees (nullable; historical
    # rows predate them). Used by the employee-list filters.
    "ALTER TABLE employees ADD COLUMN IF NOT EXISTS created_by INTEGER",
    "ALTER TABLE employees ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP",
    # "Email unavailable" flag — set at hire when no email is provided, cleared
    # once one is added; drives the amber "provide email" flag in the list.
    "ALTER TABLE employees ADD COLUMN IF NOT EXISTS "
    "email_pending BOOLEAN NOT NULL DEFAULT false",
    # Per-employee brand (which brand of a multi-brand foodmall they belong to).
    # NULL falls back to the primary store's brand.
    "ALTER TABLE employees ADD COLUMN IF NOT EXISTS brand_id INTEGER",
    # Force-password-change-at-next-login flag.
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS "
    "must_change_password BOOLEAN NOT NULL DEFAULT false",
]


def _run_migrations() -> None:
    with engine.begin() as conn:
        for stmt in _MIGRATIONS:
            conn.execute(text(stmt))


def init_db() -> None:
    # Phase 1: create tables directly from the models. Swap to Alembic migrations
    # once the schema starts changing in production.
    import app.models.models  # noqa: F401  (ensures models are registered)

    SQLModel.metadata.create_all(engine)
    _run_migrations()


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
