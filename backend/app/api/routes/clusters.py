"""Cluster administration — who manages what.

Admin / IT / HR assign:
  * each **Area Manager** the specific STORES in their cluster
    (`area_manager_stores`), and
  * each **Ops Manager** the BRAND(s) they own (`ops_manager_brands`).

This is the single place those assignments are set; the manager dashboards read
them back through `app.core.scoping`.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.core.scoping import served_brand_ids
from app.models.models import (
    AreaManagers,
    AreaManagerStores,
    AuditLogs,
    Brands,
    OpsManagerBrands,
    Stores,
    Users,
)
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1/clusters", tags=["clusters"])

# Who may SET clusters (standing request: Admins, IT and HR).
MANAGE_ROLES = ("Super Admin", "Admin", "IT", "HR")


# ---------- schemas ----------
class BrandLite(BaseModel):
    brand_id: int
    brand_name: str


class StoreLite(BaseModel):
    store_id: int
    store_name: str
    brand_id: int | None = None  # primary brand
    brand_name: str = ""  # primary brand name
    # Every brand the store serves (primary + foodmall extras). A foodmall is
    # listed under each of these in the picker.
    brand_names: list[str] = []


class AreaManagerRow(BaseModel):
    user_id: int
    username: str
    manager_id: int
    store_ids: list[int]


class OpsManagerRow(BaseModel):
    user_id: int
    username: str
    brand_ids: list[int]


class ClustersOverview(BaseModel):
    brands: list[BrandLite]
    stores: list[StoreLite]
    area_managers: list[AreaManagerRow]
    ops_managers: list[OpsManagerRow]


class SetStores(BaseModel):
    store_ids: list[int]


class SetBrands(BaseModel):
    brand_ids: list[int]


# ---------- helpers ----------
def _ensure_area_manager(session: Session, user: Users) -> AreaManagers:
    """Return the user's area-manager row, creating it if missing (mirrors the
    Users & Roles behaviour so a cluster can be set right after role change)."""
    m = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == user.user_id)
    ).first()
    if m is None:
        m = AreaManagers(user_id=user.user_id, manager_name=user.username)
        session.add(m)
        session.commit()
        session.refresh(m)
    return m


def _has_role(session: Session, user: Users, role: str) -> bool:
    """True if `role` is the user's primary or an additional role."""
    if user.role == role:
        return True
    from app.models.models import UserRoles  # local import avoids a cycle

    return (
        session.exec(
            select(UserRoles).where(
                UserRoles.user_id == user.user_id, UserRoles.role == role
            )
        ).first()
        is not None
    )


# ---------- read ----------
@router.get("/overview", response_model=ClustersOverview)
def overview(
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    tenant = current.tenant_id
    brands = session.exec(
        select(Brands).where(Brands.tenant_id == tenant).order_by(Brands.brand_name)
    ).all()
    brand_name = {b.brand_id: b.brand_name for b in brands}
    stores = session.exec(
        select(Stores).where(Stores.tenant_id == tenant).order_by(Stores.store_name)
    ).all()

    users = session.exec(
        select(Users).where(Users.tenant_id == tenant)
    ).all()

    am_rows: list[AreaManagerRow] = []
    ops_rows: list[OpsManagerRow] = []
    for u in sorted(users, key=lambda x: x.username.lower()):
        if _has_role(session, u, "Area Manager"):
            m = _ensure_area_manager(session, u)
            sids = [
                link.store_id
                for link in session.exec(
                    select(AreaManagerStores).where(
                        AreaManagerStores.manager_id == m.manager_id
                    )
                ).all()
            ]
            am_rows.append(
                AreaManagerRow(
                    user_id=u.user_id,
                    username=u.username,
                    manager_id=m.manager_id,
                    store_ids=sids,
                )
            )
        if _has_role(session, u, "Ops Manager"):
            bids = [
                link.brand_id
                for link in session.exec(
                    select(OpsManagerBrands).where(
                        OpsManagerBrands.user_id == u.user_id
                    )
                ).all()
            ]
            ops_rows.append(
                OpsManagerRow(
                    user_id=u.user_id, username=u.username, brand_ids=bids
                )
            )

    return ClustersOverview(
        brands=[BrandLite(brand_id=b.brand_id, brand_name=b.brand_name) for b in brands],
        stores=[
            StoreLite(
                store_id=s.store_id,
                store_name=s.store_name,
                brand_id=s.brand_id,
                brand_name=brand_name.get(s.brand_id, ""),
                brand_names=sorted(
                    {
                        brand_name.get(bid, "")
                        for bid in served_brand_ids(session, s)
                        if brand_name.get(bid)
                    }
                ),
            )
            for s in stores
        ],
        area_managers=am_rows,
        ops_managers=ops_rows,
    )


# ---------- write ----------
@router.put("/area-manager/{user_id}/stores", response_model=AreaManagerRow)
def set_area_manager_stores(
    user_id: int,
    payload: SetStores,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    user = session.get(Users, user_id)
    if user is None or user.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="User not found.")
    if not _has_role(session, user, "Area Manager"):
        raise HTTPException(status_code=422, detail="That user is not an Area Manager.")
    m = _ensure_area_manager(session, user)

    # Validate stores exist in-tenant; de-dupe.
    clean: list[int] = []
    for sid in payload.store_ids:
        s = session.get(Stores, sid)
        if s is None or s.tenant_id != current.tenant_id:
            raise HTTPException(status_code=422, detail=f"Unknown store id {sid}.")
        if sid not in clean:
            clean.append(sid)

    # Replace the set: delete, FLUSH, then insert (the uq_ams_manager_store
    # ordering rule — see CLAUDE.md).
    for existing in session.exec(
        select(AreaManagerStores).where(
            AreaManagerStores.manager_id == m.manager_id
        )
    ).all():
        session.delete(existing)
    session.flush()
    for sid in clean:
        session.add(AreaManagerStores(manager_id=m.manager_id, store_id=sid))
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="area_manager_stores",
            record_id=str(m.manager_id),
            old_value=None,
            new_value={"store_ids": clean},
        )
    )
    session.commit()
    return AreaManagerRow(
        user_id=user.user_id,
        username=user.username,
        manager_id=m.manager_id,
        store_ids=clean,
    )


@router.put("/ops-manager/{user_id}/brands", response_model=OpsManagerRow)
def set_ops_manager_brands(
    user_id: int,
    payload: SetBrands,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    user = session.get(Users, user_id)
    if user is None or user.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="User not found.")
    if not _has_role(session, user, "Ops Manager"):
        raise HTTPException(status_code=422, detail="That user is not an Ops Manager.")

    clean: list[int] = []
    for bid in payload.brand_ids:
        b = session.get(Brands, bid)
        if b is None or b.tenant_id != current.tenant_id:
            raise HTTPException(status_code=422, detail=f"Unknown brand id {bid}.")
        if bid not in clean:
            clean.append(bid)

    for existing in session.exec(
        select(OpsManagerBrands).where(OpsManagerBrands.user_id == user_id)
    ).all():
        session.delete(existing)
    session.flush()
    for bid in clean:
        session.add(OpsManagerBrands(user_id=user_id, brand_id=bid))
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="ops_manager_brands",
            record_id=str(user_id),
            old_value=None,
            new_value={"brand_ids": clean},
        )
    )
    session.commit()
    return OpsManagerRow(user_id=user_id, username=user.username, brand_ids=clean)
