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
    # Widen the users.role check to include 'IT'. Drop+recreate so it's idempotent
    # (Postgres has no ADD CONSTRAINT IF NOT EXISTS).
    "ALTER TABLE users DROP CONSTRAINT IF EXISTS ck_users_role",
    "ALTER TABLE users ADD CONSTRAINT ck_users_role "
    "CHECK (role IN ('Super Admin', 'Admin', 'HR', 'Area Manager', 'IT'))",
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
