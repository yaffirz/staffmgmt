"""In-process scheduler for automatic database backups.

A single APScheduler `BackgroundScheduler` (the app runs one uvicorn worker) runs
a cron job per the `backup_schedule` / `backup_time` settings. Changing the
schedule from the admin UI calls `reschedule()`.
"""
import logging

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlmodel import Session

from app.core import backup as backup_svc
from app.core.app_settings import get_setting
from app.core.database import engine

logger = logging.getLogger("app.scheduler")

_scheduler = BackgroundScheduler(daemon=True)
_JOB_ID = "scheduled_backup"
_TENANT = 1


def _job() -> None:
    """Run a scheduled backup, then prune to retention."""
    with Session(engine) as session:
        try:
            retention = int(get_setting(session, _TENANT, "backup_retention") or "10")
        except (TypeError, ValueError):
            retention = 10
        backup_svc.start_backup(session, _TENANT, "scheduled", None)
        backup_svc.prune(session, retention)


def _trigger() -> CronTrigger | None:
    with Session(engine) as session:
        sched = (get_setting(session, _TENANT, "backup_schedule") or "off").lower()
        time_s = get_setting(session, _TENANT, "backup_time") or "02:00"
    if sched not in ("daily", "weekly"):
        return None
    try:
        hh, mm = (int(x) for x in time_s.split(":"))
    except (ValueError, AttributeError):
        hh, mm = 2, 0
    if sched == "weekly":
        return CronTrigger(day_of_week="mon", hour=hh, minute=mm)
    return CronTrigger(hour=hh, minute=mm)


def reschedule() -> None:
    """(Re)register the backup job from current settings."""
    try:
        _scheduler.remove_job(_JOB_ID)
    except Exception:  # noqa: BLE001  (job may not exist)
        pass
    trig = _trigger()
    if trig is not None:
        _scheduler.add_job(_job, trig, id=_JOB_ID, replace_existing=True)
        logger.info("scheduled-backup job set: %s", trig)
    else:
        logger.info("scheduled backups are off")


def start() -> None:
    if not _scheduler.running:
        _scheduler.start()
    reschedule()
