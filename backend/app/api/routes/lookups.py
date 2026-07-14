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
    Positions,
    Stores,
)
from app.schemas.auth import CurrentUser
from app.schemas.lookups import (
    BrandCreate,
    BrandRead,
    BrandUpdate,
    BulkResult,
    BulkRowError,
    CountryRead,
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
    return session.exec(query.order_by(Stores.store_name)).all()


@router.get("/positions", response_model=list[PositionRead])
def list_positions(
    brand_id: Optional[int] = None,
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    query = select(Positions).where(Positions.tenant_id == current.tenant_id)
    if brand_id is not None:
        query = query.where(Positions.brand_id == brand_id)
    return session.exec(query.order_by(Positions.position_title)).all()


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
        tenant_id=current.tenant_id, brand_id=payload.brand_id, store_name=name
    )
    session.add(store)
    session.commit()
    session.refresh(store)
    return store


@router.post(
    "/positions", response_model=PositionRead, status_code=status.HTTP_201_CREATED
)
def create_position(
    payload: PositionCreate,
    current: CurrentUser = Depends(require_roles(*ORG_ROLES)),
    session: Session = Depends(get_session),
):
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
        raise HTTPException(
            status_code=409,
            detail=f"Position '{title}' already exists for that brand.",
        )
    position = Positions(
        tenant_id=current.tenant_id, brand_id=payload.brand_id, position_title=title
    )
    session.add(position)
    session.commit()
    session.refresh(position)
    return position


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
    old = {"brand_id": store.brand_id, "store_name": store.store_name}
    store.brand_id = payload.brand_id
    store.store_name = name
    session.add(store)
    session.commit()
    session.refresh(store)
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="stores",
            record_id=str(store.store_id),
            old_value=old,
            new_value={"brand_id": store.brand_id, "store_name": store.store_name},
        )
    )
    session.commit()
    return store


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
        raise HTTPException(
            status_code=409,
            detail=f"Position '{title}' already exists for that brand.",
        )
    old = {"brand_id": position.brand_id, "position_title": position.position_title}
    position.brand_id = payload.brand_id
    position.position_title = title
    session.add(position)
    session.commit()
    session.refresh(position)
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
            },
        )
    )
    session.commit()
    return position


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
    snap = {"brand_id": store.brand_id, "store_name": store.store_name}
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
    session.delete(position)
    session.commit()
    _audit_delete(session, current, "positions", position_id, snap)
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
