import csv
import io
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlmodel import Session, select

from app.api.deps import get_current_user, require_roles
from app.core.database import get_session
from app.models.models import (
    AuditLogs,
    Brands,
    Countries,
    Employees,
    EmployeeAdditionalStores,
    PositionBrandOptOuts,
    Positions,
    StoreBrands,
    Stores,
    StoreUsers,
)
from app.schemas.auth import CurrentUser
from app.schemas.lookups import (
    BrandCreate,
    BrandRead,
    BrandUpdate,
    BulkResult,
    BulkRowError,
    CountryCreate,
    CountryRead,
    CountryUpdate,
    PositionCreate,
    PositionRead,
    PositionUpdate,
    StoreCreate,
    StoreRead,
    StoreUpdate,
)

router = APIRouter(prefix="/api/v1", tags=["lookups"])

# Org structure (brands/stores/positions) is managed by these roles.
ORG_ROLES = ("Super Admin", "Admin")


def _extra_brand_ids(session: Session, store_id: int) -> list[int]:
    return [
        sb.brand_id
        for sb in session.exec(
            select(StoreBrands).where(StoreBrands.store_id == store_id)
        ).all()
    ]


def _position_optout_brand_ids(session: Session, position_id: int) -> list[int]:
    return [
        o.brand_id
        for o in session.exec(
            select(PositionBrandOptOuts).where(
                PositionBrandOptOuts.position_id == position_id
            )
        ).all()
    ]


def _position_read(session: Session, position: Positions) -> PositionRead:
    universal = position.brand_id is None
    return PositionRead(
        position_id=position.position_id,
        brand_id=position.brand_id,
        position_title=position.position_title,
        universal=universal,
        disabled_brand_ids=(
            _position_optout_brand_ids(session, position.position_id)
            if universal
            else []
        ),
    )


def _set_position_optouts(
    session: Session, position: Positions, brand_ids: list[int], tenant: int
) -> None:
    """Replace a universal position's per-brand opt-outs (validated, in-tenant).
    Clears all opt-outs when the position isn't universal."""
    clean: list[int] = []
    if position.brand_id is None:
        for bid in brand_ids:
            if bid in clean:
                continue
            b = session.get(Brands, bid)
            if b is None or b.tenant_id != tenant:
                raise HTTPException(
                    status_code=422, detail=f"Unknown brand id {bid}."
                )
            clean.append(bid)
    for existing in session.exec(
        select(PositionBrandOptOuts).where(
            PositionBrandOptOuts.position_id == position.position_id
        )
    ).all():
        session.delete(existing)
    for bid in clean:
        session.add(
            PositionBrandOptOuts(position_id=position.position_id, brand_id=bid)
        )
    session.commit()


def _store_read(session: Session, store: Stores) -> StoreRead:
    return StoreRead(
        store_id=store.store_id,
        brand_id=store.brand_id,
        store_name=store.store_name,
        is_foodmall=store.is_foodmall,
        extra_brand_ids=_extra_brand_ids(session, store.store_id),
    )


def _set_store_brands(
    session: Session, store: Stores, brand_ids: list[int], tenant: int
) -> None:
    """Replace a foodmall store's extra brands (validated, in-tenant, excluding
    the primary brand). Clears all extras when the store isn't a foodmall."""
    clean: list[int] = []
    if store.is_foodmall:
        for bid in brand_ids:
            if bid == store.brand_id or bid in clean:
                continue
            b = session.get(Brands, bid)
            if b is None or b.tenant_id != tenant:
                raise HTTPException(status_code=422, detail=f"Unknown brand id {bid}.")
            clean.append(bid)
    for existing in session.exec(
        select(StoreBrands).where(StoreBrands.store_id == store.store_id)
    ).all():
        session.delete(existing)
    for bid in clean:
        session.add(StoreBrands(store_id=store.store_id, brand_id=bid))
    session.commit()


# ---- Read (any authenticated user) ---------------------------------------
@router.get("/brands", response_model=list[BrandRead])
def list_brands(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return session.exec(
        select(Brands)
        .where(Brands.tenant_id == current.tenant_id)
        .order_by(Brands.brand_name)
    ).all()


@router.get("/stores", response_model=list[StoreRead])
def list_stores(
    brand_id: Optional[int] = None,
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    query = select(Stores).where(Stores.tenant_id == current.tenant_id)
    if brand_id is not None:
        query = query.where(Stores.brand_id == brand_id)
    stores = session.exec(query.order_by(Stores.store_name)).all()
    return [_store_read(session, s) for s in stores]


@router.get("/positions", response_model=list[PositionRead])
def list_positions(
    brand_id: Optional[int] = None,
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    positions = session.exec(
        select(Positions)
        .where(Positions.tenant_id == current.tenant_id)
        .order_by(Positions.position_title)
    ).all()
    reads = [_position_read(session, p) for p in positions]
    if brand_id is not None:
        # A brand sees its own positions plus universal roles not opted out.
        reads = [
            r
            for r in reads
            if r.brand_id == brand_id
            or (r.universal and brand_id not in r.disabled_brand_ids)
        ]
    return reads


@router.get("/countries", response_model=list[CountryRead])
def list_countries(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return session.exec(select(Countries).order_by(Countries.country_name)).all()


# ---- Create (single) -----------------------------------------------------
@router.post("/brands", response_model=BrandRead, status_code=status.HTTP_201_CREATED)
def create_brand(
    payload: BrandCreate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    name = payload.brand_name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Brand name is required.")
    existing = session.exec(
        select(Brands).where(
            Brands.tenant_id == current.tenant_id, Brands.brand_name == name
        )
    ).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail=f"Brand '{name}' already exists.")
    brand = Brands(tenant_id=current.tenant_id, brand_name=name)
    session.add(brand)
    session.commit()
    session.refresh(brand)
    return brand


@router.post("/stores", response_model=StoreRead, status_code=status.HTTP_201_CREATED)
def create_store(
    payload: StoreCreate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    brand = session.get(Brands, payload.brand_id)
    if brand is None or brand.tenant_id != current.tenant_id:
        raise HTTPException(status_code=400, detail="Unknown brand.")
    name = payload.store_name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Store name is required.")
    existing = session.exec(
        select(Stores).where(
            Stores.tenant_id == current.tenant_id,
            Stores.brand_id == payload.brand_id,
            Stores.store_name == name,
        )
    ).first()
    if existing is not None:
        raise HTTPException(
            status_code=409, detail=f"Store '{name}' already exists for that brand."
        )
    store = Stores(
        tenant_id=current.tenant_id,
        brand_id=payload.brand_id,
        store_name=name,
        is_foodmall=payload.is_foodmall,
    )
    session.add(store)
    session.commit()
    session.refresh(store)
    _set_store_brands(session, store, payload.extra_brand_ids, current.tenant_id)
    return _store_read(session, store)


@router.post(
    "/positions", response_model=PositionRead, status_code=status.HTTP_201_CREATED
)
def create_position(
    payload: PositionCreate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    if payload.brand_id is not None:
        brand = session.get(Brands, payload.brand_id)
        if brand is None or brand.tenant_id != current.tenant_id:
            raise HTTPException(status_code=400, detail="Unknown brand.")
    title = payload.position_title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="Position title is required.")
    existing = session.exec(
        select(Positions).where(
            Positions.tenant_id == current.tenant_id,
            Positions.brand_id == payload.brand_id,
            Positions.position_title == title,
        )
    ).first()
    if existing is not None:
        scope = "as a universal role" if payload.brand_id is None else "for that brand"
        raise HTTPException(
            status_code=409,
            detail=f"Position '{title}' already exists {scope}.",
        )
    position = Positions(
        tenant_id=current.tenant_id, brand_id=payload.brand_id, position_title=title
    )
    session.add(position)
    session.commit()
    session.refresh(position)
    _set_position_optouts(
        session, position, payload.disabled_brand_ids, current.tenant_id
    )
    return _position_read(session, position)


@router.post(
    "/countries", response_model=CountryRead, status_code=status.HTTP_201_CREATED
)
def create_country(
    payload: CountryCreate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    # Countries are a global lookup (no tenant), shared across the staff form.
    name = payload.country_name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Country name is required.")
    taken = {
        c.country_name.strip().lower()
        for c in session.exec(select(Countries)).all()
    }
    if name.lower() in taken:
        raise HTTPException(status_code=409, detail=f"Country '{name}' already exists.")
    country = Countries(country_name=name)
    session.add(country)
    session.commit()
    session.refresh(country)
    return country


@router.patch("/brands/{brand_id}", response_model=BrandRead)
def update_brand(
    brand_id: int,
    payload: BrandUpdate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    brand = session.get(Brands, brand_id)
    if brand is None or brand.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Brand not found.")
    name = payload.brand_name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Brand name is required.")
    clash = session.exec(
        select(Brands).where(
            Brands.tenant_id == current.tenant_id,
            Brands.brand_name == name,
            Brands.brand_id != brand_id,
        )
    ).first()
    if clash is not None:
        raise HTTPException(status_code=409, detail=f"Brand '{name}' already exists.")
    old = brand.brand_name
    brand.brand_name = name
    session.add(brand)
    session.commit()
    session.refresh(brand)
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="brands",
            record_id=str(brand.brand_id),
            old_value={"brand_name": old},
            new_value={"brand_name": name},
        )
    )
    session.commit()
    return brand


@router.patch("/stores/{store_id}", response_model=StoreRead)
def update_store(
    store_id: int,
    payload: StoreUpdate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    store = session.get(Stores, store_id)
    if store is None or store.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Store not found.")
    brand = session.get(Brands, payload.brand_id)
    if brand is None or brand.tenant_id != current.tenant_id:
        raise HTTPException(status_code=400, detail="Unknown brand.")
    name = payload.store_name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Store name is required.")
    clash = session.exec(
        select(Stores).where(
            Stores.tenant_id == current.tenant_id,
            Stores.brand_id == payload.brand_id,
            Stores.store_name == name,
            Stores.store_id != store_id,
        )
    ).first()
    if clash is not None:
        raise HTTPException(
            status_code=409, detail=f"Store '{name}' already exists for that brand."
        )
    old = {
        "brand_id": store.brand_id,
        "store_name": store.store_name,
        "is_foodmall": store.is_foodmall,
    }
    store.brand_id = payload.brand_id
    store.store_name = name
    store.is_foodmall = payload.is_foodmall
    session.add(store)
    session.commit()
    session.refresh(store)
    _set_store_brands(session, store, payload.extra_brand_ids, current.tenant_id)
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="stores",
            record_id=str(store.store_id),
            old_value=old,
            new_value={
                "brand_id": store.brand_id,
                "store_name": store.store_name,
                "is_foodmall": store.is_foodmall,
                "extra_brand_ids": _extra_brand_ids(session, store.store_id),
            },
        )
    )
    session.commit()
    return _store_read(session, store)


@router.patch("/positions/{position_id}", response_model=PositionRead)
def update_position(
    position_id: int,
    payload: PositionUpdate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    position = session.get(Positions, position_id)
    if position is None or position.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Position not found.")
    if payload.brand_id is not None:
        brand = session.get(Brands, payload.brand_id)
        if brand is None or brand.tenant_id != current.tenant_id:
            raise HTTPException(status_code=400, detail="Unknown brand.")
    title = payload.position_title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="Position title is required.")
    clash = session.exec(
        select(Positions).where(
            Positions.tenant_id == current.tenant_id,
            Positions.brand_id == payload.brand_id,
            Positions.position_title == title,
            Positions.position_id != position_id,
        )
    ).first()
    if clash is not None:
        scope = "as a universal role" if payload.brand_id is None else "for that brand"
        raise HTTPException(
            status_code=409,
            detail=f"Position '{title}' already exists {scope}.",
        )
    old = {
        "brand_id": position.brand_id,
        "position_title": position.position_title,
        "disabled_brand_ids": _position_optout_brand_ids(session, position_id),
    }
    position.brand_id = payload.brand_id
    position.position_title = title
    session.add(position)
    session.commit()
    session.refresh(position)
    _set_position_optouts(
        session, position, payload.disabled_brand_ids, current.tenant_id
    )
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="positions",
            record_id=str(position.position_id),
            old_value=old,
            new_value={
                "brand_id": position.brand_id,
                "position_title": position.position_title,
                "disabled_brand_ids": _position_optout_brand_ids(
                    session, position_id
                ),
            },
        )
    )
    session.commit()
    return _position_read(session, position)


@router.patch("/countries/{country_id}", response_model=CountryRead)
def update_country(
    country_id: int,
    payload: CountryUpdate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    country = session.get(Countries, country_id)
    if country is None:
        raise HTTPException(status_code=404, detail="Country not found.")
    name = payload.country_name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Country name is required.")
    clash = session.exec(
        select(Countries).where(Countries.country_id != country_id)
    ).all()
    if any(c.country_name.strip().lower() == name.lower() for c in clash):
        raise HTTPException(status_code=409, detail=f"Country '{name}' already exists.")
    old = country.country_name
    country.country_name = name
    session.add(country)
    session.commit()
    session.refresh(country)
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="countries",
            record_id=str(country.country_id),
            old_value={"country_name": old},
            new_value={"country_name": name},
        )
    )
    session.commit()
    return country


def _audit_delete(session, current, table, record_id, snapshot):
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="DELETE",
            affected_table=table,
            record_id=str(record_id),
            old_value=snapshot,
            new_value=None,
        )
    )


@router.delete("/brands/{brand_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_brand(
    brand_id: int,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    brand = session.get(Brands, brand_id)
    if brand is None or brand.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Brand not found.")
    n_stores = len(
        session.exec(select(Stores).where(Stores.brand_id == brand_id)).all()
    )
    n_pos = len(
        session.exec(
            select(Positions).where(Positions.brand_id == brand_id)
        ).all()
    )
    if n_stores or n_pos:
        parts = []
        if n_stores:
            parts.append(f"{n_stores} store(s)")
        if n_pos:
            parts.append(f"{n_pos} position(s)")
        raise HTTPException(
            status_code=409,
            detail=f"Cannot delete '{brand.brand_name}' — it still has "
            f"{' and '.join(parts)}.",
        )
    snap = {"brand_name": brand.brand_name}
    session.delete(brand)
    session.commit()
    _audit_delete(session, current, "brands", brand_id, snap)
    session.commit()
    return None


@router.delete("/stores/{store_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_store(
    store_id: int,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    store = session.get(Stores, store_id)
    if store is None or store.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Store not found.")
    n_primary = len(
        session.exec(
            select(Employees).where(Employees.primary_store_id == store_id)
        ).all()
    )
    n_extra = len(
        session.exec(
            select(EmployeeAdditionalStores).where(
                EmployeeAdditionalStores.store_id == store_id
            )
        ).all()
    )
    total = n_primary + n_extra
    if total:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot delete '{store.store_name}' — "
            f"{total} employee assignment(s) reference it.",
        )
    n_accounts = len(
        session.exec(
            select(StoreUsers).where(StoreUsers.store_id == store_id)
        ).all()
    )
    if n_accounts:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot delete '{store.store_name}' — "
            f"{n_accounts} Store/Foodmall account(s) are bound to it.",
        )
    snap = {"brand_id": store.brand_id, "store_name": store.store_name}
    # Foodmall brand links have no employee references — safe to drop.
    for sb in session.exec(
        select(StoreBrands).where(StoreBrands.store_id == store_id)
    ).all():
        session.delete(sb)
    session.delete(store)
    session.commit()
    _audit_delete(session, current, "stores", store_id, snap)
    session.commit()
    return None


@router.delete(
    "/positions/{position_id}", status_code=status.HTTP_204_NO_CONTENT
)
def delete_position(
    position_id: int,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    position = session.get(Positions, position_id)
    if position is None or position.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Position not found.")
    n_emp = len(
        session.exec(
            select(Employees).where(Employees.position_id == position_id)
        ).all()
    )
    if n_emp:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot delete '{position.position_title}' — "
            f"{n_emp} employee(s) hold it.",
        )
    snap = {
        "brand_id": position.brand_id,
        "position_title": position.position_title,
    }
    # Universal-role opt-outs reference this position — clear them first.
    for o in session.exec(
        select(PositionBrandOptOuts).where(
            PositionBrandOptOuts.position_id == position_id
        )
    ).all():
        session.delete(o)
    session.delete(position)
    session.commit()
    _audit_delete(session, current, "positions", position_id, snap)
    session.commit()
    return None


@router.delete("/countries/{country_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_country(
    country_id: int,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    country = session.get(Countries, country_id)
    if country is None:
        raise HTTPException(status_code=404, detail="Country not found.")
    n_emp = len(
        session.exec(
            select(Employees).where(Employees.country_id == country_id)
        ).all()
    )
    if n_emp:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot delete '{country.country_name}' — "
            f"{n_emp} employee(s) reference it.",
        )
    snap = {"country_name": country.country_name}
    session.delete(country)
    session.commit()
    _audit_delete(session, current, "countries", country_id, snap)
    session.commit()
    return None


# ---- Bulk (CSV upload) ---------------------------------------------------
def _parse_csv(raw: bytes, required: list[str]):
    """Returns (rows, error). Each row is a dict with lowercased, trimmed keys."""
    text = raw.decode("utf-8-sig", errors="replace")
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames is None:
        return [], "The file appears to be empty."
    headers = [(h or "").strip().lower() for h in reader.fieldnames]
    missing = [c for c in required if c not in headers]
    if missing:
        return [], f"Missing required column(s): {', '.join(missing)}"
    rows = []
    for r in reader:
        rows.append({(k or "").strip().lower(): (v or "").strip() for k, v in r.items()})
    return rows, None


@router.post("/brands/bulk", response_model=BulkResult)
async def bulk_brands(
    file: UploadFile = File(...),
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    """CSV columns: brand_name"""
    rows, err = _parse_csv(await file.read(), ["brand_name"])
    if err:
        raise HTTPException(status_code=400, detail=err)

    existing = {
        b.brand_name.lower()
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    created = skipped = 0
    errors: list[BulkRowError] = []
    for i, row in enumerate(rows, start=2):
        name = row.get("brand_name", "").strip()
        if not name:
            errors.append(BulkRowError(row=i, message="brand_name is empty"))
            continue
        if name.lower() in existing:
            skipped += 1
            continue
        session.add(Brands(tenant_id=current.tenant_id, brand_name=name))
        existing.add(name.lower())
        created += 1
    session.commit()
    return BulkResult(created=created, skipped=skipped, errors=errors)


@router.post("/stores/bulk", response_model=BulkResult)
async def bulk_stores(
    file: UploadFile = File(...),
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    """CSV columns: brand_name, store_name  (brand must already exist)"""
    rows, err = _parse_csv(await file.read(), ["brand_name", "store_name"])
    if err:
        raise HTTPException(status_code=400, detail=err)

    brands = {
        b.brand_name.lower(): b.brand_id
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    existing = {
        (s.brand_id, s.store_name.lower())
        for s in session.exec(
            select(Stores).where(Stores.tenant_id == current.tenant_id)
        ).all()
    }
    created = skipped = 0
    errors: list[BulkRowError] = []
    for i, row in enumerate(rows, start=2):
        bn = row.get("brand_name", "").strip()
        sn = row.get("store_name", "").strip()
        if not bn or not sn:
            errors.append(
                BulkRowError(row=i, message="brand_name and store_name are required")
            )
            continue
        bid = brands.get(bn.lower())
        if bid is None:
            errors.append(BulkRowError(row=i, message=f"Unknown brand '{bn}'"))
            continue
        if (bid, sn.lower()) in existing:
            skipped += 1
            continue
        session.add(
            Stores(tenant_id=current.tenant_id, brand_id=bid, store_name=sn)
        )
        existing.add((bid, sn.lower()))
        created += 1
    session.commit()
    return BulkResult(created=created, skipped=skipped, errors=errors)


@router.post("/positions/bulk", response_model=BulkResult)
async def bulk_positions(
    file: UploadFile = File(...),
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
    """CSV columns: brand_name, position_title  (brand must already exist)"""
    rows, err = _parse_csv(await file.read(), ["brand_name", "position_title"])
    if err:
        raise HTTPException(status_code=400, detail=err)

    brands = {
        b.brand_name.lower(): b.brand_id
        for b in session.exec(
            select(Brands).where(Brands.tenant_id == current.tenant_id)
        ).all()
    }
    existing = {
        (p.brand_id, p.position_title.lower())
        for p in session.exec(
            select(Positions).where(Positions.tenant_id == current.tenant_id)
        ).all()
    }
    created = skipped = 0
    errors: list[BulkRowError] = []
    for i, row in enumerate(rows, start=2):
        bn = row.get("brand_name", "").strip()
        pt = row.get("position_title", "").strip()
        if not bn or not pt:
            errors.append(
                BulkRowError(
                    row=i, message="brand_name and position_title are required"
                )
            )
            continue
        bid = brands.get(bn.lower())
        if bid is None:
            errors.append(BulkRowError(row=i, message=f"Unknown brand '{bn}'"))
            continue
        if (bid, pt.lower()) in existing:
            skipped += 1
            continue
        session.add(
            Positions(tenant_id=current.tenant_id, brand_id=bid, position_title=pt)
        )
        existing.add((bid, pt.lower()))
        created += 1
    session.commit()
    return BulkResult(created=created, skipped=skipped, errors=errors)
