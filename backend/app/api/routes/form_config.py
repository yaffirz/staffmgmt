from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.models.models import AuditLogs, FormFieldConfig
from app.schemas.auth import CurrentUser
from app.schemas.form_config import (
    FormConfigUpdate,
    FormFieldConfigRead,
)

router = APIRouter(prefix="/api/v1/form-config", tags=["form-config"])

WRITE_ROLES = ("Super Admin", "Admin", "HR")
ADMIN_ROLES = ("Super Admin", "Admin")


def _read(c: FormFieldConfig) -> FormFieldConfigRead:
    return FormFieldConfigRead(
        form_key=c.form_key,
        field_key=c.field_key,
        label=c.label,
        enabled=c.enabled,
        required=c.required,
        locked=c.locked,
        sort_order=c.sort_order,
    )


@router.get("/{form_key}", response_model=list[FormFieldConfigRead])
def get_form_config(
    form_key: str,
    current: CurrentUser = Depends(require_roles(*WRITE_ROLES)),
    session: Session = Depends(get_session),
):
    """Return the field configuration for a form, ordered for display."""
    tenant = current.tenant_id
    rows = session.exec(
        select(FormFieldConfig)
        .where(FormFieldConfig.tenant_id == tenant)
        .where(FormFieldConfig.form_key == form_key)
        .order_by(FormFieldConfig.sort_order)
    ).all()
    return [_read(r) for r in rows]


@router.patch("/{form_key}", response_model=list[FormFieldConfigRead])
def update_form_config(
    form_key: str,
    payload: FormConfigUpdate,
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Update enabled/required for a form's fields (Admin / Super Admin).

    Locked (structural) fields are ignored — they cannot be changed.
    """
    tenant = current.tenant_id
    existing = {
        c.field_key: c
        for c in session.exec(
            select(FormFieldConfig)
            .where(FormFieldConfig.tenant_id == tenant)
            .where(FormFieldConfig.form_key == form_key)
        ).all()
    }
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No configuration found for this form.",
        )

    changes: list[dict] = []
    for upd in payload.fields:
        cfg = existing.get(upd.field_key)
        if cfg is None or cfg.locked:
            continue  # unknown or structural field — skip
        if cfg.enabled != upd.enabled or cfg.required != upd.required:
            changes.append(
                {
                    "field_key": cfg.field_key,
                    "old": {"enabled": cfg.enabled, "required": cfg.required},
                    "new": {"enabled": upd.enabled, "required": upd.required},
                }
            )
            cfg.enabled = upd.enabled
            # A field that's disabled can't also be required.
            cfg.required = upd.required and upd.enabled
            session.add(cfg)

    if changes:
        session.commit()
        session.add(
            AuditLogs(
                user_id=current.user_id,
                action="UPDATE",
                affected_table="form_field_config",
                record_id=form_key,
                old_value=None,
                new_value={"changes": changes},
            )
        )
        session.commit()

    rows = session.exec(
        select(FormFieldConfig)
        .where(FormFieldConfig.tenant_id == tenant)
        .where(FormFieldConfig.form_key == form_key)
        .order_by(FormFieldConfig.sort_order)
    ).all()
    return [_read(r) for r in rows]
