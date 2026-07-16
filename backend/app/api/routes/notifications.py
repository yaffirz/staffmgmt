"""Notification inbox (read side). Notifications are written by other flows
(e.g. Move/Request) targeting either a specific user or a role. Read state is
per-user via `notification_reads`, so a role-broadcast stays unread for each
recipient until they personally read it.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from app.api.deps import get_current_user
from app.core.database import get_session
from app.models.models import NotificationReads, Notifications
from app.schemas.auth import CurrentUser
from app.schemas.notification import NotificationRead, UnreadCount

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])

# Max rows returned by the inbox list.
LIST_CAP = 100


def _visible_roles(current: CurrentUser) -> set[str]:
    """Which recipient_role values this user should receive — the union over all
    their effective roles. Super Admin sits above Admin, so it also sees
    Admin-targeted notifications."""
    out: set[str] = set()
    for r in current.roles or [current.role]:
        out.add(r)
        if r == "Super Admin":
            out.add("Admin")
    return out


def _my_notifications(current: CurrentUser, session: Session) -> list[Notifications]:
    """All notifications targeted at this user (by user id or by role), newest
    first, within the tenant."""
    roles = _visible_roles(current)
    rows = session.exec(
        select(Notifications)
        .where(Notifications.tenant_id == current.tenant_id)
        .order_by(Notifications.created_at.desc())
    ).all()
    mine = []
    for n in rows:
        if n.recipient_user_id is not None:
            if n.recipient_user_id == current.user_id:
                mine.append(n)
        elif n.recipient_role is not None and n.recipient_role in roles:
            mine.append(n)
    return mine


def _read_ids(current: CurrentUser, session: Session) -> set[int]:
    return {
        r.notification_id
        for r in session.exec(
            select(NotificationReads).where(
                NotificationReads.user_id == current.user_id
            )
        ).all()
    }


@router.get("", response_model=list[NotificationRead])
def list_notifications(
    unread_only: bool = Query(False),
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """List the current user's notifications (newest first)."""
    mine = _my_notifications(current, session)
    read_ids = _read_ids(current, session)
    out: list[NotificationRead] = []
    for n in mine:
        is_read = n.notification_id in read_ids
        if unread_only and is_read:
            continue
        out.append(
            NotificationRead(
                notification_id=n.notification_id,
                type=n.type,
                payload=n.payload,
                is_read=is_read,
                created_at=n.created_at,
            )
        )
        if len(out) >= LIST_CAP:
            break
    return out


@router.get("/unread-count", response_model=UnreadCount)
def unread_count(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Count of the current user's unread notifications (for the bell badge)."""
    mine = _my_notifications(current, session)
    read_ids = _read_ids(current, session)
    count = sum(1 for n in mine if n.notification_id not in read_ids)
    return UnreadCount(count=count)


@router.post("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_read(
    notification_id: int,
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Mark one notification read for the current user. Must be targeted to them."""
    notif = session.get(Notifications, notification_id)
    if notif is None or notif.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Notification not found.")

    # Authorise: the notification must actually target this user.
    targeted = (
        notif.recipient_user_id == current.user_id
        if notif.recipient_user_id is not None
        else (
            notif.recipient_role is not None
            and notif.recipient_role in _visible_roles(current)
        )
    )
    if not targeted:
        raise HTTPException(status_code=404, detail="Notification not found.")

    existing = session.exec(
        select(NotificationReads).where(
            NotificationReads.notification_id == notification_id,
            NotificationReads.user_id == current.user_id,
        )
    ).first()
    if existing is None:
        session.add(
            NotificationReads(
                notification_id=notification_id, user_id=current.user_id
            )
        )
        session.commit()
    return None


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
def mark_all_read(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Mark all of the current user's notifications read."""
    mine = _my_notifications(current, session)
    read_ids = _read_ids(current, session)
    added = False
    for n in mine:
        if n.notification_id not in read_ids:
            session.add(
                NotificationReads(
                    notification_id=n.notification_id, user_id=current.user_id
                )
            )
            added = True
    if added:
        session.commit()
    return None
