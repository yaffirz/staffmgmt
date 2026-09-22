"""Self-service registration foundation: public sign-up -> email confirmation
(stubbed sender) -> admin approval, which creates the real Users account.

Kept in its own `registration_requests` table so existing login is untouched.
Gated by the `registration_enabled` setting (off by default).
"""
import secrets

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import HTMLResponse
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.api.routes.users import (
    STORE_ROLES,
    _manager_for,
    _set_brands,
    _set_store_link,
)
from app.core.app_settings import get_bool
from app.core.database import get_session
from app.core.email import compose_message, send_email
from app.core.security import hash_password
from app.models.models import (
    ALLOWED_ROLES as MODEL_ALLOWED_ROLES,
    AuditLogs,
    RegistrationRequests,
    Users,
)
from app.schemas.auth import CurrentUser
from app.schemas.registration import (
    ApproveRequest,
    RegisterRequest,
    RegisterResult,
    RegistrationRead,
)

router = APIRouter(prefix="/api/v1", tags=["registration"])

ADMIN_ROLES = ("Super Admin", "Admin")
ALLOWED_ROLES = set(MODEL_ALLOWED_ROLES)
_TENANT_ID = 1
_OPEN = ("pending_email", "pending_approval")

_NEUTRAL = RegisterResult(
    status="pending",
    message="Thanks! Check your email to confirm your address. "
    "An administrator will then review your account.",
)


def _valid_email(email: str) -> str:
    e = email.strip()
    if not e or "@" not in e or "." not in e.split("@")[-1]:
        raise HTTPException(status_code=422, detail="A valid email is required.")
    return e


def _page(title: str, body: str) -> str:
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>"
        f"<title>{title}</title></head>"
        "<body style='font-family:system-ui,sans-serif;background:#0F3D3E;"
        "color:#fff;display:flex;min-height:100vh;align-items:center;"
        "justify-content:center;margin:0'>"
        "<div style='max-width:420px;padding:32px;text-align:center'>"
        f"<h1 style='color:#E9A23B'>{title}</h1>"
        f"<p style='line-height:1.5;color:#dfeceb'>{body}</p></div>"
        "</body></html>"
    )


@router.get("/register/enabled")
def registration_enabled(session: Session = Depends(get_session)):
    """Public: whether self-registration is on (login shows the link if so)."""
    return {
        "enabled": get_bool(session, _TENANT_ID, "registration_enabled", False)
    }


@router.post("/register", response_model=RegisterResult)
def register(payload: RegisterRequest, session: Session = Depends(get_session)):
    if not get_bool(session, _TENANT_ID, "registration_enabled", False):
        raise HTTPException(
            status_code=403, detail="Self-registration is currently disabled."
        )
    username = payload.username.strip()
    if not username:
        raise HTTPException(status_code=422, detail="Username is required.")
    email = _valid_email(payload.email)
    if len(payload.password) < 6:
        raise HTTPException(
            status_code=422, detail="Password must be at least 6 characters."
        )

    # Silently no-op on duplicates (against real users or open requests) so the
    # endpoint never reveals whether a username/email exists.
    taken = session.exec(
        select(Users)
        .where(Users.tenant_id == _TENANT_ID)
        .where((Users.username == username) | (Users.email == email))
    ).first()
    dup = session.exec(
        select(RegistrationRequests)
        .where(
            RegistrationRequests.tenant_id == _TENANT_ID,
            RegistrationRequests.status.in_(_OPEN),
        )
        .where(
            (RegistrationRequests.username == username)
            | (RegistrationRequests.email == email)
        )
    ).first()
    if taken is not None or dup is not None:
        return _NEUTRAL

    token = secrets.token_urlsafe(32)
    req = RegistrationRequests(
        tenant_id=_TENANT_ID,
        username=username,
        email=email,
        password_hash=hash_password(payload.password),
        status="pending_email",
        email_token=token,
        note=(payload.note.strip() if payload.note else None),
    )
    session.add(req)
    session.commit()
    confirm = f"/api/v1/register/confirm?token={token}"
    body_tpl = (
        f"Confirm your email address to continue: {confirm}\n\n<signature>"
    )
    text, html = compose_message(session, _TENANT_ID, body_tpl, {})
    send_email(
        email, "Confirm your Staff Portal registration", text, html=html
    )
    return _NEUTRAL


@router.get("/register/confirm", response_class=HTMLResponse)
def confirm(token: str = Query(...), session: Session = Depends(get_session)):
    req = session.exec(
        select(RegistrationRequests).where(
            RegistrationRequests.email_token == token
        )
    ).first()
    if req is None:
        return HTMLResponse(
            _page("Link not valid", "This confirmation link is not valid."),
            status_code=404,
        )
    if req.status == "pending_email":
        req.email_verified = True
        req.status = "pending_approval"
        session.add(req)
        session.commit()
        return HTMLResponse(
            _page(
                "Email confirmed",
                "Thanks — your email is confirmed. An administrator will "
                "review your account shortly.",
            )
        )
    if req.email_verified:
        return HTMLResponse(
            _page(
                "Already confirmed",
                "Your email was already confirmed. An administrator will "
                "review your account.",
            )
        )
    return HTMLResponse(_page("Nothing to do", "This request is no longer pending."))


@router.get("/registrations", response_model=list[RegistrationRead])
def list_registrations(
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    rows = session.exec(
        select(RegistrationRequests)
        .where(RegistrationRequests.tenant_id == current.tenant_id)
        .order_by(RegistrationRequests.created_at.desc())
    ).all()
    return [
        RegistrationRead(
            id=r.id,
            username=r.username,
            email=r.email,
            status=r.status,
            email_verified=r.email_verified,
            note=r.note,
            created_at=r.created_at,
            confirm_path=(
                f"/api/v1/register/confirm?token={r.email_token}"
                if r.status in _OPEN
                else None
            ),
        )
        for r in rows
    ]


@router.post("/registrations/{req_id}/approve")
def approve(
    req_id: int,
    payload: ApproveRequest,
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    req = session.get(RegistrationRequests, req_id)
    if req is None or req.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Request not found.")
    if req.status in ("approved", "rejected"):
        raise HTTPException(status_code=409, detail=f"Request already {req.status}.")
    if payload.role not in ALLOWED_ROLES:
        raise HTTPException(status_code=422, detail="Unknown role.")
    if payload.role in STORE_ROLES and payload.store_id is None:
        raise HTTPException(
            status_code=422,
            detail="A store is required for Store/Foodmall accounts.",
        )
    # Guard against a real account being created in the meantime.
    if session.exec(
        select(Users)
        .where(Users.tenant_id == current.tenant_id)
        .where((Users.username == req.username) | (Users.email == req.email))
    ).first():
        raise HTTPException(
            status_code=409,
            detail="A user with that username or email already exists.",
        )

    user = Users(
        tenant_id=current.tenant_id,
        username=req.username,
        email=req.email,
        password_hash=req.password_hash,  # already hashed at registration
        role=payload.role,
    )
    session.add(user)
    session.commit()
    session.refresh(user)

    if payload.role == "Area Manager":
        m = _manager_for(session, user)
        _set_brands(session, m.manager_id, payload.brand_ids or [], current.tenant_id)
    if payload.role in STORE_ROLES:
        _set_store_link(session, user, payload.store_id, current.tenant_id)

    req.status = "approved"
    req.reviewed_by = current.user_id
    session.add(req)
    session.commit()

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="users",
            record_id=str(user.user_id),
            old_value=None,
            new_value={
                "via": "registration",
                "username": user.username,
                "role": user.role,
            },
        )
    )
    session.commit()
    return {"status": "approved", "user_id": user.user_id}


@router.post("/registrations/{req_id}/reject")
def reject(
    req_id: int,
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    req = session.get(RegistrationRequests, req_id)
    if req is None or req.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Request not found.")
    if req.status in ("approved", "rejected"):
        raise HTTPException(status_code=409, detail=f"Request already {req.status}.")
    req.status = "rejected"
    req.reviewed_by = current.user_id
    session.add(req)
    session.commit()
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="registration_requests",
            record_id=str(req.id),
            old_value=None,
            new_value={"status": "rejected"},
        )
    )
    session.commit()
    return {"status": "rejected"}
