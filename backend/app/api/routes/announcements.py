"""Announcements — a Super Admin broadcasts a custom message to everyone.

An announcement is just a Notification with type "ANNOUNCEMENT" and a broadcast
recipient (`recipient_role = "All"`), so it reuses the whole notification inbox /
read-state machinery. The `payload.display` field decides the channel:
  - "bell"  → shows only in the notification bell (like any notification).
  - "popup" → ALSO surfaces as a one-time dialog the first time each user sees it
              (dismissal is the normal per-user read, via `notification_reads`).
"""
from fastapi import APIRouter, Depends, status
from sqlmodel import Session

from app.api.deps import get_current_user, require_roles
from app.api.routes.notifications import (
    BROADCAST_ROLE,
    _my_notifications,
    _read_ids,
)
from app.core.database import get_session
from app.models.models import AuditLogs, Notifications
from app.schemas.announcement import (
    DELIVERY_POPUP,
    AnnouncementCreate,
    AnnouncementResult,
)
from app.schemas.auth import CurrentUser
from app.schemas.notification import NotificationRead

router = APIRouter(prefix="/api/v1/announcements", tags=["announcements"])

# Only a Super Admin may broadcast an announcement.
CREATE_ROLES = ("Super Admin",)

ANNOUNCEMENT_TYPE = "ANNOUNCEMENT"


@router.post("", response_model=AnnouncementResult, status_code=status.HTTP_201_CREATED)
def create_announcement(
    payload: AnnouncementCreate,
    current: CurrentUser = Depends(require_roles(*CREATE_ROLES)),
    session: Session = Depends(get_session),
):
    """Broadcast an announcement to every user (Super Admin only)."""
    notif = Notifications(
        tenant_id=current.tenant_id,
        recipient_role=BROADCAST_ROLE,
        type=ANNOUNCEMENT_TYPE,
        payload={
            "title": payload.title,
            "body": payload.body,
            "display": payload.delivery,
            "by_username": current.username,
        },
    )
    session.add(notif)
    session.commit()
    session.refresh(notif)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="notifications",
            record_id=str(notif.notification_id),
            old_value=None,
            new_value={
                "type": ANNOUNCEMENT_TYPE,
                "display": payload.delivery,
                "title": payload.title,
            },
        )
    )
    session.commit()

    return AnnouncementResult(
        notification_id=notif.notification_id, delivery=payload.delivery
    )


@router.get("/popup", response_model=list[NotificationRead])
def popup_announcements(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Unread popup-type announcements for the current user (newest first).

    The client shows these as one-time dialogs, then marks each read via the
    normal `POST /notifications/{id}/read`, so they never reappear."""
    mine = _my_notifications(current, session)
    read_ids = _read_ids(current, session)
    out: list[NotificationRead] = []
    for n in mine:
        if n.type != ANNOUNCEMENT_TYPE:
            continue
        if (n.payload or {}).get("display") != DELIVERY_POPUP:
            continue
        if n.notification_id in read_ids:
            continue
        out.append(
            NotificationRead(
                notification_id=n.notification_id,
                type=n.type,
                payload=n.payload,
                is_read=False,
                created_at=n.created_at,
            )
        )
    return out
