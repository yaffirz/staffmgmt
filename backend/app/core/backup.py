"""Database backups via `pg_dump`.

Runs the dump in a background thread so the request returns immediately; the
`Backups` row tracks status (running -> completed | failed), size and timing.
Files land in BACKUP_DIR (bind-mounted to the host in docker-compose).
"""
import logging
import os
import subprocess
import threading

from sqlalchemy.engine import make_url
from sqlmodel import Session, select

from app.core.config import settings
from app.core.database import engine
from app.models.models import Backups, utcnow

logger = logging.getLogger("app.backup")

BACKUP_DIR = os.getenv("BACKUP_DIR", "/code/backups")


def _run_pg_dump(dest_path: str) -> None:
    """Dump the whole database to dest_path. Raises on failure."""
    url = make_url(settings.DATABASE_URL)
    env = dict(os.environ)
    if url.password:
        env["PGPASSWORD"] = url.password
    args = [
        "pg_dump",
        "-h", url.host or "db",
        "-p", str(url.port or 5432),
        "-U", url.username or "postgres",
        "-d", url.database,
        "-f", dest_path,
        "--no-owner",
        "--no-privileges",
    ]
    subprocess.run(args, env=env, check=True, capture_output=True, text=True)


def _perform(backup_id: int) -> None:
    """Background worker: run the dump and update the row."""
    with Session(engine) as session:
        row = session.get(Backups, backup_id)
        if row is None:
            return
        dest = os.path.join(BACKUP_DIR, row.filename)
        try:
            os.makedirs(BACKUP_DIR, exist_ok=True)
            _run_pg_dump(dest)
            row.size_bytes = os.path.getsize(dest) if os.path.exists(dest) else 0
            row.status = "completed"
        except subprocess.CalledProcessError as e:
            row.status = "failed"
            row.error = (e.stderr or str(e))[:500]
            logger.error("backup %s failed: %s", backup_id, row.error)
        except Exception as e:  # noqa: BLE001
            row.status = "failed"
            row.error = str(e)[:500]
            logger.exception("backup %s errored", backup_id)
        row.finished_at = utcnow()
        session.add(row)
        session.commit()


def start_backup(
    session: Session, tenant_id: int, kind: str, created_by: int | None
) -> Backups:
    """Create a `running` row and kick off the dump in a daemon thread."""
    ts = utcnow().strftime("%Y%m%d-%H%M%S")
    row = Backups(
        tenant_id=tenant_id,
        filename=f"staffmgmt-{ts}.sql",
        status="running",
        kind=kind,
        created_by=created_by,
    )
    session.add(row)
    session.commit()
    session.refresh(row)
    threading.Thread(target=_perform, args=(row.id,), daemon=True).start()
    return row


def prune(session: Session, retention: int) -> None:
    """Keep the most recent `retention` backups; delete older files + rows."""
    if retention < 1:
        retention = 1
    rows = session.exec(
        select(Backups).order_by(Backups.started_at.desc())
    ).all()
    for old in rows[retention:]:
        path = os.path.join(BACKUP_DIR, old.filename)
        try:
            if os.path.exists(path):
                os.remove(path)
        except OSError:
            logger.warning("could not delete backup file %s", path)
        session.delete(old)
    session.commit()
