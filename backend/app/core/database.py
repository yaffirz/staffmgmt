from collections.abc import Generator

from sqlmodel import Session, SQLModel, create_engine

from app.core.config import settings

# pool_pre_ping avoids "server closed the connection" after idle periods.
engine = create_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True)


def init_db() -> None:
    # Phase 1: create tables directly from the models. Swap to Alembic migrations
    # once the schema starts changing in production.
    import app.models.models  # noqa: F401  (ensures models are registered)

    SQLModel.metadata.create_all(engine)


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
