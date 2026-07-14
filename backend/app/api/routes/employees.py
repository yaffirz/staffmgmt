import csv
import io
from datetime import datetime

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.core.database import get_session
from app.models.models import (
    AuditLogs,
    Brands,
    Countries,
    Employees,
    EmployeeAdditionalStores,
    FormFieldConfig,
    Positions,
    StaffNotes,
    StaffStatusLog,
    Stores,
)
from app.schemas.auth import CurrentUser
from app.schemas.employee import (
    EmployeeCreate,
    EmployeeRead,
    MagUpdate,
    ReviewUpdate,
)
from app.schemas.lookups import BulkResult, BulkRowError

router = APIRouter(prefix="/api/v1/employees", tags=["employees"])

# Per the endpoint matrix: only these roles create/list employees.
WRITE_ROLES = ("Super Admin", "Admin", "HR")
ADMIN_ROLES = ("Super Admin", "Admin")


def _validate_config_required(
    payload: EmployeeCreate, session: Session, tenant: int
) -> None:
    """Enforce required-ness of configurable fields per the form config.
    Locked/structural fields are already required by the schema."""
    configs = session.exec(
        select(FormFieldConfig)
        .where(FormFieldConfig.tenant_id == tenant)
        .where(FormFieldConfig.form_key == "employee")
    ).all()

    def present(field_key: str) -> bool:
        if field_key == "email":
            return bool((payload.email or "").strip())
        if field_key == "payrate":
            return payload.payrate is not None
        if field_key == "pay_currency":
            return bool((payload.pay_currency or "").strip())
        if field_key == "phone_number":
            return bool((payload.phone_number or "").strip())
        if field_key == "mag_code":
            return bool((payload.mag_code or "").strip())
        if field_key == "country_id":
            return payload.country_id is not None
        if field_key == "additional_store_ids":
            return bool(payload.additional_store_ids)
        return True  # locked fields handled by the schema

    missing = [
        c.label
        for c in configs
        if c.enabled and c.required and not c.locked and not present(c.field_key)
    ]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Missing required field(s): {', '.join(missing)}.",
        )


def _additional_stores(
    emp: Employees, session: Session, store_name_by_id: dict[int, str] | None = None
) -> tuple[list[str], list[int]]:
    """Resolve names and ids of an employee's additional stores."""
    links = session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.employee_id == emp.employee_id
        )
    ).all()
    pairs: list[tuple[str, int]] = []
    for link in links:
        if store_name_by_id is not None:
            name = store_name_by_id.get(link.store_id)
        else:
            st = session.get(Stores, link.store_id)
            name = st.store_name if st else None
        if name:
            pairs.append((name, link.store_id))
    pairs.sort(key=lambda p: p[0])
    return [p[0] for p in pairs], [p[1] for p in pairs]


def _enrich(emp: Employees, session: Session) -> EmployeeRead:
    """Build an EmployeeRead with resolved store/brand/position/country names."""
    store = (
        session.get(Stores, emp.primary_store_id)
        if emp.primary_store_id is not None
        else None
    )
    brand = (
        session.get(Brands, store.brand_id)
        if store is not None
        else None
    )
    position = (
        session.get(Positions, emp.position_id)
        if emp.position_id is not None
        else None
    )
    country = (
        session.get(Countries, emp.country_id)
        if emp.country_id is not None
        else None
    )
    add_names, add_ids = _additional_stores(emp, session)
    return EmployeeRead(
        employee_id=emp.employee_id,
        tenant_id=emp.tenant_id,
        payroll_id=emp.payroll_id,
        employee_name=emp.employee_name,
        date_of_birth=emp.date_of_birth,
        phone_number=emp.phone_number,
        email=emp.email,
        payrate=emp.payrate,
        pay_currency=emp.pay_currency,
        mag_code=emp.mag_code,
        country_id=emp.country_id,
        primary_store_id=emp.primary_store_id,
        position_id=emp.position_id,
        reviewed=emp.reviewed,
        created_at=emp.created_at,
        store_name=store.store_name if store else None,
        brand_name=brand.brand_name if brand else None,
        position_title=position.position_title if position else None,
        country_name=country.country_name if country else None,
        additional_stores=add_names,
        additional_store_ids=add_ids,
    )


@router.post("", response_model=EmployeeRead, status_code=status.HTTP_201_CREATED)
def create_employee(
    payload: EmployeeCreate,
    current: CurrentUser = Depends(require_roles(*WRITE_ROLES)),
    session: Session = Depends(get_session),
):
    """Ingest a new hire. payroll_id must be unique within the tenant."""
    tenant = current.tenant_id

    duplicate = session.exec(
        select(Employees).where(
            Employees.tenant_id == tenant,
            Employees.payroll_id == payload.payroll_id,
        )
    ).first()
    if duplicate is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"An employee with payroll ID '{payload.payroll_id}' already exists.",
        )

    _validate_config_required(payload, session, tenant)

    if payload.primary_store_id is not None:
        store = session.get(Stores, payload.primary_store_id)
        if store is None or store.tenant_id != tenant:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected primary store does not exist.",
            )
    if payload.position_id is not None:
        position = session.get(Positions, payload.position_id)
        if position is None or position.tenant_id != tenant:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected position does not exist.",
            )
    if payload.country_id is not None:
        country = session.get(Countries, payload.country_id)
        if country is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected country does not exist.",
            )

    # Validate optional additional stores (dedupe, must exist in tenant).
    add_store_ids: list[int] = []
    if payload.additional_store_ids:
        for sid in payload.additional_store_ids:
            if sid in add_store_ids or sid == payload.primary_store_id:
                continue
            st = session.get(Stores, sid)
            if st is None or st.tenant_id != tenant:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="An additional store does not exist.",
                )
            add_store_ids.append(sid)

    employee = Employees(
        tenant_id=tenant,
        payroll_id=payload.payroll_id,
        employee_name=payload.employee_name,
        date_of_birth=payload.date_of_birth,
        phone_number=payload.phone_number,
        email=payload.email,
        payrate=payload.payrate,
        pay_currency=payload.pay_currency,
        mag_code=payload.mag_code,
        country_id=payload.country_id,
        primary_store_id=payload.primary_store_id,
        position_id=payload.position_id,
    )
    session.add(employee)
    session.commit()
    session.refresh(employee)

    # Persist additional store assignments (junction table).
    for sid in add_store_ids:
        session.add(
            EmployeeAdditionalStores(
                employee_id=employee.employee_id, store_id=sid
            )
        )
    if add_store_ids:
        session.commit()

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="employees",
            record_id=str(employee.employee_id),
            old_value=None,
            new_value={
                "payroll_id": employee.payroll_id,
                "employee_name": employee.employee_name,
                "date_of_birth": employee.date_of_birth.isoformat(),
                "primary_store_id": employee.primary_store_id,
                "position_id": employee.position_id,
            },
        )
    )
    session.commit()

    return _enrich(employee, session)


@router.get("", response_model=list[EmployeeRead])
def list_employees(
    current: CurrentUser = Depends(require_roles(*WRITE_ROLES)),
    session: Session = Depends(get_session),
):
    """List all employees in the tenant, newest first, with resolved names."""
    tenant = current.tenant_id
    employees = session.exec(
        select(Employees)
        .where(Employees.tenant_id == tenant)
        .order_by(Employees.created_at.desc())
    ).all()

    # Preload lookups once and map by id (avoids a query per row).
    stores = {
        s.store_id: s
        for s in session.exec(select(Stores).where(Stores.tenant_id == tenant)).all()
    }
    brands = {
        b.brand_id: b
        for b in session.exec(select(Brands).where(Brands.tenant_id == tenant)).all()
    }
    positions = {
        p.position_id: p
        for p in session.exec(
            select(Positions).where(Positions.tenant_id == tenant)
        ).all()
    }
    countries = {c.country_id: c for c in session.exec(select(Countries)).all()}

    # Preload additional-store links for all listed employees in one query.
    store_name_by_id = {sid: s.store_name for sid, s in stores.items()}
    emp_ids = [e.employee_id for e in employees]
    add_names_by_emp: dict[int, list[str]] = {}
    add_ids_by_emp: dict[int, list[int]] = {}
    if emp_ids:
        links = session.exec(
            select(EmployeeAdditionalStores).where(
                EmployeeAdditionalStores.employee_id.in_(emp_ids)
            )
        ).all()
        for link in links:
            nm = store_name_by_id.get(link.store_id)
            if nm:
                add_names_by_emp.setdefault(link.employee_id, []).append(nm)
                add_ids_by_emp.setdefault(link.employee_id, []).append(
                    link.store_id
                )
        for v in add_names_by_emp.values():
            v.sort()

    result: list[EmployeeRead] = []
    for emp in employees:
        store = stores.get(emp.primary_store_id)
        brand = brands.get(store.brand_id) if store else None
        position = positions.get(emp.position_id)
        country = countries.get(emp.country_id)
        result.append(
            EmployeeRead(
                employee_id=emp.employee_id,
                tenant_id=emp.tenant_id,
                payroll_id=emp.payroll_id,
                employee_name=emp.employee_name,
                date_of_birth=emp.date_of_birth,
                phone_number=emp.phone_number,
                email=emp.email,
                payrate=emp.payrate,
                pay_currency=emp.pay_currency,
                mag_code=emp.mag_code,
                country_id=emp.country_id,
                primary_store_id=emp.primary_store_id,
                position_id=emp.position_id,
                reviewed=emp.reviewed,
                created_at=emp.created_at,
                store_name=store.store_name if store else None,
                brand_name=brand.brand_name if brand else None,
                position_title=position.position_title if position else None,
                country_name=country.country_name if country else None,
                additional_stores=add_names_by_emp.get(emp.employee_id, []),
                additional_store_ids=add_ids_by_emp.get(emp.employee_id, []),
            )
        )
    return result


@router.patch("/{employee_id}/reviewed", response_model=EmployeeRead)
def set_reviewed(
    employee_id: int,
    payload: ReviewUpdate,
    current: CurrentUser = Depends(require_roles(*WRITE_ROLES)),
    session: Session = Depends(get_session),
):
    """Mark an employee row reviewed / un-reviewed (persistent, shared)."""
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found."
        )

    old = emp.reviewed
    emp.reviewed = payload.reviewed
    session.add(emp)
    session.commit()
    session.refresh(emp)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="employees",
            record_id=str(emp.employee_id),
            old_value={"reviewed": old},
            new_value={"reviewed": emp.reviewed},
        )
    )
    session.commit()

    return _enrich(emp, session)


@router.get("/next-mag")
def next_mag_code(
    current: CurrentUser = Depends(require_roles(*WRITE_ROLES)),
    session: Session = Depends(get_session),
):
    """Suggest the next MAG card number, auto-incrementing from 70000000."""
    base = 70000000
    tenant = current.tenant_id
    employees = session.exec(
        select(Employees).where(Employees.tenant_id == tenant)
    ).all()
    highest = base - 1
    for emp in employees:
        code = (emp.mag_code or "").strip()
        if code.isdigit():
            n = int(code)
            if n >= base and n > highest:
                highest = n
    return {"mag_code": str(highest + 1)}


@router.patch("/{employee_id}/mag-code", response_model=EmployeeRead)
def update_mag_code(
    employee_id: int,
    payload: MagUpdate,
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Update an employee's MAG card number (Admin / Super Admin only)."""
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found."
        )

    old = emp.mag_code
    new = (payload.mag_code or "").strip() or None
    emp.mag_code = new
    session.add(emp)
    session.commit()
    session.refresh(emp)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="employees",
            record_id=str(emp.employee_id),
            old_value={"mag_code": old},
            new_value={"mag_code": new},
        )
    )
    session.commit()

    return _enrich(emp, session)


@router.put("/{employee_id}", response_model=EmployeeRead)
def update_employee(
    employee_id: int,
    payload: EmployeeCreate,
    current: CurrentUser = Depends(require_roles(*WRITE_ROLES)),
    session: Session = Depends(get_session),
):
    """Update an existing employee. Same validation rules as create."""
    tenant = current.tenant_id
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found."
        )

    # payroll_id must stay unique within the tenant (excluding this record).
    duplicate = session.exec(
        select(Employees).where(
            Employees.tenant_id == tenant,
            Employees.payroll_id == payload.payroll_id,
            Employees.employee_id != employee_id,
        )
    ).first()
    if duplicate is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"An employee with payroll ID '{payload.payroll_id}' already exists.",
        )

    _validate_config_required(payload, session, tenant)

    store = session.get(Stores, payload.primary_store_id)
    if store is None or store.tenant_id != tenant:
        raise HTTPException(status_code=400, detail="Primary store does not exist.")
    position = session.get(Positions, payload.position_id)
    if position is None or position.tenant_id != tenant:
        raise HTTPException(status_code=400, detail="Position does not exist.")
    if payload.country_id is not None:
        country = session.get(Countries, payload.country_id)
        if country is None:
            raise HTTPException(status_code=400, detail="Selected country does not exist.")

    # Validate additional stores.
    add_store_ids: list[int] = []
    if payload.additional_store_ids:
        for sid in payload.additional_store_ids:
            if sid in add_store_ids or sid == payload.primary_store_id:
                continue
            st = session.get(Stores, sid)
            if st is None or st.tenant_id != tenant:
                raise HTTPException(
                    status_code=400, detail="An additional store does not exist."
                )
            add_store_ids.append(sid)

    old_value = {
        "payroll_id": emp.payroll_id,
        "employee_name": emp.employee_name,
        "primary_store_id": emp.primary_store_id,
        "position_id": emp.position_id,
    }

    emp.payroll_id = payload.payroll_id
    emp.employee_name = payload.employee_name
    emp.date_of_birth = payload.date_of_birth
    emp.email = payload.email
    emp.payrate = payload.payrate
    emp.pay_currency = payload.pay_currency
    emp.phone_number = payload.phone_number
    emp.mag_code = payload.mag_code
    emp.country_id = payload.country_id
    emp.primary_store_id = payload.primary_store_id
    emp.position_id = payload.position_id
    session.add(emp)
    session.commit()

    # Replace additional-store assignments.
    existing_links = session.exec(
        select(EmployeeAdditionalStores).where(
            EmployeeAdditionalStores.employee_id == employee_id
        )
    ).all()
    for link in existing_links:
        session.delete(link)
    for sid in add_store_ids:
        session.add(
            EmployeeAdditionalStores(employee_id=employee_id, store_id=sid)
        )
    session.commit()
    session.refresh(emp)

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="UPDATE",
            affected_table="employees",
            record_id=str(emp.employee_id),
            old_value=old_value,
            new_value={
                "payroll_id": emp.payroll_id,
                "employee_name": emp.employee_name,
                "primary_store_id": emp.primary_store_id,
                "position_id": emp.position_id,
            },
        )
    )
    session.commit()

    return _enrich(emp, session)


@router.delete("/{employee_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_employee(
    employee_id: int,
    current: CurrentUser = Depends(require_roles(*ADMIN_ROLES)),
    session: Session = Depends(get_session),
):
    """Delete an employee and its dependent rows (Admin / Super Admin only)."""
    tenant = current.tenant_id
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != tenant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Employee not found."
        )

    snapshot = {
        "payroll_id": emp.payroll_id,
        "employee_name": emp.employee_name,
    }

    # Remove dependent rows first to satisfy foreign keys.
    for model in (EmployeeAdditionalStores, StaffNotes, StaffStatusLog):
        rows = session.exec(
            select(model).where(model.employee_id == employee_id)
        ).all()
        for r in rows:
            session.delete(r)

    session.delete(emp)
    session.commit()

    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="DELETE",
            affected_table="employees",
            record_id=str(employee_id),
            old_value=snapshot,
            new_value=None,
        )
    )
    session.commit()
    return None


# CSV columns. Structural columns are always required; the rest follow the
# form config. Additional stores are semicolon-separated within one cell.
_BULK_REQUIRED_COLS = [
    "payroll_id",
    "employee_name",
    "date_of_birth",
    "brand_name",
    "store_name",
    "position_title",
]


@router.post("/bulk", response_model=BulkResult)
async def bulk_employees(
    file: UploadFile = File(...),
    current: CurrentUser = Depends(require_roles(*WRITE_ROLES)),
    session: Session = Depends(get_session),
):
    """Best-effort CSV import of employees. Returns per-row results.

    Columns: payroll_id, employee_name, date_of_birth (MM/DD/YYYY),
    brand_name, store_name, position_title, email, payrate, pay_currency,
    phone_number, mag_code, country_name, additional_stores (semicolon list).
    """
    tenant = current.tenant_id

    raw = await file.read()
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("latin-1")

    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames is None:
        raise HTTPException(status_code=400, detail="CSV has no header row.")
    field_map = {(h or "").strip().lower(): h for h in reader.fieldnames}
    missing_cols = [c for c in _BULK_REQUIRED_COLS if c not in field_map]
    if missing_cols:
        raise HTTPException(
            status_code=400,
            detail=f"Missing required column(s): {', '.join(missing_cols)}.",
        )

    # Lookups
    brands = session.exec(
        select(Brands).where(Brands.tenant_id == tenant)
    ).all()
    brand_by_name = {b.brand_name.strip().lower(): b for b in brands}
    stores = session.exec(
        select(Stores).where(Stores.tenant_id == tenant)
    ).all()
    store_by_key = {
        (s.brand_id, s.store_name.strip().lower()): s for s in stores
    }
    positions = session.exec(
        select(Positions).where(Positions.tenant_id == tenant)
    ).all()
    pos_by_key = {
        (p.brand_id, p.position_title.strip().lower()): p for p in positions
    }
    countries = session.exec(select(Countries)).all()
    country_by_name = {c.country_name.strip().lower(): c for c in countries}

    configs = {
        c.field_key: c
        for c in session.exec(
            select(FormFieldConfig)
            .where(FormFieldConfig.tenant_id == tenant)
            .where(FormFieldConfig.form_key == "employee")
        ).all()
    }

    def required(key: str) -> bool:
        c = configs.get(key)
        return bool(c and c.enabled and c.required)

    employees = session.exec(
        select(Employees).where(Employees.tenant_id == tenant)
    ).all()
    existing_payrolls = {e.payroll_id for e in employees}
    mag_next = 70000000
    for e in employees:
        code = (e.mag_code or "").strip()
        if code.isdigit() and int(code) >= mag_next:
            mag_next = int(code) + 1

    created = 0
    skipped = 0
    errors: list[BulkRowError] = []
    batch_payrolls: set[str] = set()

    for idx, row in enumerate(reader, start=2):
        def cell(key: str) -> str:
            return (row.get(field_map.get(key, ""), "") or "").strip()

        payroll = cell("payroll_id")
        try:
            if not payroll:
                raise ValueError("payroll_id is required")
            if payroll in existing_payrolls or payroll in batch_payrolls:
                skipped += 1
                continue

            name = cell("employee_name")
            if not name:
                raise ValueError("employee_name is required")

            dob_raw = cell("date_of_birth")
            if not dob_raw:
                raise ValueError("date_of_birth is required")
            try:
                dob = datetime.strptime(dob_raw, "%m/%d/%Y").date()
            except ValueError:
                raise ValueError(
                    f"date_of_birth '{dob_raw}' must be MM/DD/YYYY"
                )

            brand_name = cell("brand_name")
            brand = brand_by_name.get(brand_name.lower())
            if brand is None:
                raise ValueError(f"Unknown brand '{brand_name}'")

            store_name = cell("store_name")
            store = store_by_key.get((brand.brand_id, store_name.lower()))
            if store is None:
                raise ValueError(
                    f"Unknown store '{store_name}' for brand '{brand_name}'"
                )

            pos_title = cell("position_title")
            position = pos_by_key.get((brand.brand_id, pos_title.lower()))
            if position is None:
                raise ValueError(
                    f"Unknown position '{pos_title}' for brand '{brand_name}'"
                )

            email = cell("email") or None
            payrate_raw = cell("payrate")
            payrate = None
            if payrate_raw:
                try:
                    payrate = float(payrate_raw)
                except ValueError:
                    raise ValueError(f"payrate '{payrate_raw}' is not a number")
                if payrate < 0:
                    raise ValueError("payrate cannot be negative")
            currency = cell("pay_currency") or None
            phone = cell("phone_number") or None
            mag = cell("mag_code") or None

            country_name = cell("country_name")
            country = None
            if country_name:
                country = country_by_name.get(country_name.lower())
                if country is None:
                    raise ValueError(f"Unknown country '{country_name}'")

            add_raw = cell("additional_stores")
            add_ids: list[int] = []
            if add_raw:
                for nm in add_raw.split(";"):
                    nm = nm.strip()
                    if not nm:
                        continue
                    st = store_by_key.get((brand.brand_id, nm.lower()))
                    if st is None:
                        raise ValueError(
                            f"Unknown additional store '{nm}'"
                        )
                    if (
                        st.store_id != store.store_id
                        and st.store_id not in add_ids
                    ):
                        add_ids.append(st.store_id)

            # Config-required validation (mag is auto-assigned, so skip it).
            checks = {
                "email": email,
                "payrate": payrate,
                "pay_currency": currency,
                "phone_number": phone,
                "country_id": country,
                "additional_store_ids": add_ids,
            }
            missing = []
            for key, val in checks.items():
                if required(key):
                    empty = val is None or (
                        isinstance(val, (list, str)) and len(val) == 0
                    )
                    if empty:
                        missing.append(configs[key].label)
            if missing:
                raise ValueError(
                    "Missing required: " + ", ".join(missing)
                )

            # Auto-assign MAG if blank (after validation, to avoid gaps).
            if not mag:
                mag = str(mag_next)
                mag_next += 1

            emp = Employees(
                tenant_id=tenant,
                payroll_id=payroll,
                employee_name=name,
                date_of_birth=dob,
                email=email,
                payrate=payrate,
                pay_currency=currency,
                phone_number=phone,
                mag_code=mag,
                country_id=country.country_id if country else None,
                primary_store_id=store.store_id,
                position_id=position.position_id,
            )
            session.add(emp)
            session.commit()
            session.refresh(emp)
            for sid in add_ids:
                session.add(
                    EmployeeAdditionalStores(
                        employee_id=emp.employee_id, store_id=sid
                    )
                )
            if add_ids:
                session.commit()

            existing_payrolls.add(payroll)
            batch_payrolls.add(payroll)
            created += 1
        except ValueError as ve:
            errors.append(BulkRowError(row=idx, message=str(ve)))
        except Exception:
            session.rollback()
            errors.append(
                BulkRowError(row=idx, message="Could not import this row.")
            )

    if created:
        session.add(
            AuditLogs(
                user_id=current.user_id,
                action="INSERT",
                affected_table="employees",
                record_id="bulk",
                old_value=None,
                new_value={"created": created, "skipped": skipped},
            )
        )
        session.commit()

    return BulkResult(created=created, skipped=skipped, errors=errors)
