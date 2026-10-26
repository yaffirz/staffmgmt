"""Non-Oracle employees.

IT / Admins mark which brands are NOT on Oracle; every employee of a non-Oracle
brand then appears in the Non-Oracle Employees list, with a per-employee override
to force an individual in or out regardless of their brand. This list is the
roster the future fingerprint clock-in system will be tied to.
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.api.routes.employees import _effective_brand_id, _enrich
from app.core.database import get_session
from app.models.models import AuditLogs, Brands, Employees, Stores
from app.schemas.auth import CurrentUser
from app.schemas.employee import EmployeeRead

router = APIRouter(prefix="/api/v1/non-oracle", tags=["non-oracle"])

# Who may mark brands and move employees in/out of the non-Oracle list.
MANAGE_ROLES = ("Super Admin", "Admin", "IT")


class BrandNonOracle(BaseModel):
    brand_id: int
    brand_name: str
    non_oracle: bool


class BrandFlagUpdate(BaseModel):
    non_oracle: bool


class EmployeeOverrideUpdate(BaseModel):
    # NULL = follow the brand, True = force into the list, False = force out.
    override: Optional[bool] = None


@router.get("/brands", response_model=list[BrandNonOracle])
def list_brands(
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """All brands with their non-Oracle flag, for the marking UI."""
    brands = session.exec(
        select(Brands)
        .where(Brands.tenant_id == current.tenant_id)
        .order_by(Brands.brand_name)
    ).all()
    return [
        BrandNonOracle(
            brand_id=b.brand_id,
            brand_name=b.brand_name,
            non_oracle=b.non_oracle,
        )
        for b in brands
    ]


@router.patch("/brands/{brand_id}", response_model=BrandNonOracle)
def set_brand_non_oracle(
    brand_id: int,
    payload: BrandFlagUpdate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """Mark a brand as (not) on Oracle. Marking a brand non-Oracle auto-includes
    all its employees in the list, except any individually forced out."""
    brand = session.get(Brands, brand_id)
    if brand is None or brand.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Brand not found.")
    old = brand.non_oracle
    if old != payload.non_oracle:
        brand.non_oracle = payload.non_oracle
        session.add(brand)
        session.add(
            AuditLogs(
                user_id=current.user_id,
                action="UPDATE",
                affected_table="brands",
                record_id=str(brand.brand_id),
                old_value={"non_oracle": old},
                new_value={"non_oracle": brand.non_oracle},
            )
        )
        session.commit()
        session.refresh(brand)
    return BrandNonOracle(
        brand_id=brand.brand_id,
        brand_name=brand.brand_name,
        non_oracle=brand.non_oracle,
    )


def _is_member(emp: Employees, store: Optional[Stores], non_oracle_brands: set[int]) -> bool:
    """Whether an employee belongs in the non-Oracle list: a per-employee override
    wins, otherwise membership follows the (effective) brand's flag."""
    if emp.non_oracle_override is not None:
        return emp.non_oracle_override
    eff_brand = _effective_brand_id(emp, store)
    return eff_brand is not None and eff_brand in non_oracle_brands


@router.get("/employees", response_model=list[EmployeeRead])
def list_non_oracle_employees(
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """Employees currently in the non-Oracle list (brand-driven plus/minus
    per-employee overrides), newest first — same shape as the employee list."""
    tenant = current.tenant_id
    non_oracle_brands = {
        b.brand_id
        for b in session.exec(
            select(Brands).where(
                Brands.tenant_id == tenant, Brands.non_oracle == True  # noqa: E712
            )
        ).all()
    }
    stores = {
        s.store_id: s
        for s in session.exec(select(Stores).where(Stores.tenant_id == tenant)).all()
    }
    employees = session.exec(
        select(Employees)
        .where(Employees.tenant_id == tenant)
        .order_by(Employees.created_at.desc())
    ).all()
    return [
        _enrich(emp, session)
        for emp in employees
        if _is_member(emp, stores.get(emp.primary_store_id), non_oracle_brands)
    ]


@router.patch("/employees/{employee_id}", response_model=EmployeeRead)
def set_employee_override(
    employee_id: int,
    payload: EmployeeOverrideUpdate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """Move an employee into (override=True) or out of (override=False) the
    non-Oracle list regardless of their brand, or clear the override
    (override=NULL) to follow the brand again."""
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")
    old = emp.non_oracle_override
    if old != payload.override:
        emp.non_oracle_override = payload.override
        session.add(emp)
        session.add(
            AuditLogs(
                user_id=current.user_id,
                action="UPDATE",
                affected_table="employees",
                record_id=str(emp.employee_id),
                old_value={"non_oracle_override": old},
                new_value={"non_oracle_override": emp.non_oracle_override},
            )
        )
        session.commit()
        session.refresh(emp)
    return _enrich(emp, session)
