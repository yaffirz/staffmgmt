"""Shared role-scoping helpers for the manager dashboards.

The management hierarchy is:

    Ops Manager  >  Area Manager  >  store managers / supervisors  >  staff

- **Admin roles** (Super Admin / Admin / IT / HR) see everything.
- An **Ops Manager** owns whole BRAND(s) (`ops_manager_brands`) and sees every
  store in them — i.e. all of the Area Managers' clusters within those brands.
- An **Area Manager** owns a cluster of specific STORES (`area_manager_stores`).
  Usually those stores all belong to one brand, but the set is free-form so an
  AM can span brands when needed. For backward compatibility, an AM who still
  has only the legacy BRAND links (`area_manager_brands`) and no explicit store
  cluster falls back to "every store in those brands".

`dashboard_scope` returns the brand ids and store ids a caller may see; `None`
for either means "no restriction" (admin roles).
"""
from typing import Optional

from sqlmodel import Session, select

from app.models.models import (
    AreaManagerBrands,
    AreaManagers,
    AreaManagerStores,
    Employees,
    OpsManagerBrands,
    Stores,
)
from app.schemas.auth import CurrentUser

# Roles that are not scoped to a brand/store cluster — they see the whole tenant.
ADMIN_SCOPE_ROLES = {"Super Admin", "Admin", "IT", "HR"}


def roles_of(current: CurrentUser) -> set[str]:
    return set(current.roles or [current.role])


def is_admin_scope(current: CurrentUser) -> bool:
    return bool(ADMIN_SCOPE_ROLES & roles_of(current))


def ops_brand_ids(session: Session, user_id: int) -> set[int]:
    """Brand ids an Ops Manager owns."""
    return {
        link.brand_id
        for link in session.exec(
            select(OpsManagerBrands).where(OpsManagerBrands.user_id == user_id)
        ).all()
    }


def am_manager(session: Session, user_id: int) -> Optional[AreaManagers]:
    return session.exec(
        select(AreaManagers).where(AreaManagers.user_id == user_id)
    ).first()


def stores_in_brands(
    session: Session, tenant: int, brand_ids: set[int]
) -> set[int]:
    if not brand_ids:
        return set()
    return {
        s.store_id
        for s in session.exec(
            select(Stores).where(
                Stores.tenant_id == tenant,
                Stores.brand_id.in_(brand_ids),
            )
        ).all()
    }


def am_cluster_store_ids(
    session: Session, user_id: int, tenant: int
) -> set[int]:
    """The store ids in an Area Manager's cluster.

    Explicit `area_manager_stores` wins; if none are set we fall back to every
    store in the AM's legacy brand links so pre-existing AMs keep working until
    an admin assigns them a store-level cluster.
    """
    mgr = am_manager(session, user_id)
    if mgr is None:
        return set()
    explicit = {
        link.store_id
        for link in session.exec(
            select(AreaManagerStores).where(
                AreaManagerStores.manager_id == mgr.manager_id
            )
        ).all()
    }
    if explicit:
        return explicit
    brand_ids = {
        link.brand_id
        for link in session.exec(
            select(AreaManagerBrands).where(
                AreaManagerBrands.manager_id == mgr.manager_id
            )
        ).all()
    }
    return stores_in_brands(session, tenant, brand_ids)


def brands_of_stores(session: Session, store_ids: set[int]) -> set[int]:
    if not store_ids:
        return set()
    return {
        s.brand_id
        for s in session.exec(
            select(Stores).where(Stores.store_id.in_(store_ids))
        ).all()
    }


def dashboard_scope(
    session: Session, current: CurrentUser
) -> tuple[Optional[set[int]], Optional[set[int]]]:
    """Return (brand_ids, store_ids) this caller may see. `None` = unrestricted.

    Admin roles are checked first and win even if the user also happens to hold
    a manager role, so an Admin who is also an Area Manager still sees all.
    """
    if is_admin_scope(current):
        return None, None
    roles = roles_of(current)
    tenant = current.tenant_id
    if "Ops Manager" in roles:
        brands = ops_brand_ids(session, current.user_id)
        return brands, stores_in_brands(session, tenant, brands)
    if "Area Manager" in roles:
        stores = am_cluster_store_ids(session, current.user_id, tenant)
        return brands_of_stores(session, stores), stores
    # No scope role at all → sees nothing.
    return set(), set()


def effective_brand_id(emp: Employees, store: Optional[Stores]) -> Optional[int]:
    """Which brand a staffer counts under: their explicit `brand_id` (set for
    multi-brand foodmall staff) else their primary store's brand."""
    if emp.brand_id is not None:
        return emp.brand_id
    return store.brand_id if store is not None else None
