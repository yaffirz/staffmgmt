from sqlmodel import Session, select

from app.core.config import settings
from app.core.security import hash_password
from app.core.app_settings import DEFAULTS as SETTING_DEFAULTS
from app.models.models import (
    AppSettings,
    AreaManagerBrands,
    AreaManagers,
    Brands,
    Countries,
    FormFieldConfig,
    Positions,
    Stores,
    Users,
)


def seed_initial_data(session: Session) -> None:
    """Idempotent: safe to run on every startup. Seeds a default country, a
    Super Admin, and some sample org data so the new-hire form has dropdown
    options on day one."""
    tenant = settings.DEFAULT_TENANT_ID

    # Default country (blueprint default = Trinidad).
    has_country = session.exec(select(Countries)).first()
    if has_country is None:
        session.add(Countries(country_name="Trinidad"))

    # Super Admin for the default tenant.
    existing_admin = session.exec(
        select(Users).where(
            Users.username == settings.SEED_ADMIN_USERNAME,
            Users.tenant_id == tenant,
        )
    ).first()
    if existing_admin is None:
        session.add(
            Users(
                tenant_id=tenant,
                username=settings.SEED_ADMIN_USERNAME,
                password_hash=hash_password(settings.SEED_ADMIN_PASSWORD),
                role="Super Admin",
            )
        )

    session.commit()

    _seed_org_data(session, tenant)
    _seed_form_config(session, tenant)
    _seed_app_settings(session, tenant)
    _seed_dev_area_manager(session, tenant)


def _seed_app_settings(session: Session, tenant: int) -> None:
    """Idempotent: ensure known feature-toggle rows exist at their defaults."""
    added = False
    for key, value in SETTING_DEFAULTS.items():
        exists = session.exec(
            select(AppSettings).where(
                AppSettings.tenant_id == tenant, AppSettings.key == key
            )
        ).first()
        if exists is None:
            session.add(AppSettings(tenant_id=tenant, key=key, value=value))
            added = True
    if added:
        session.commit()


def _seed_dev_area_manager(session: Session, tenant: int) -> None:
    """Dev-only, idempotent: ensure a known-credentials Area Manager exists over
    the configured brand so the Phase 2 cluster flows can be exercised. Skipped
    when SEED_DEV_AREA_MANAGER is false. Creates no employees — it relies on the
    brand's existing stores/staff."""
    if not settings.SEED_DEV_AREA_MANAGER:
        return

    # Only link to a brand that actually exists in this tenant.
    brand = session.exec(
        select(Brands).where(
            Brands.tenant_id == tenant,
            Brands.brand_name == settings.SEED_AM_BRAND_NAME,
        )
    ).first()
    if brand is None:
        return

    # 1. User (role = Area Manager).
    user = session.exec(
        select(Users).where(
            Users.tenant_id == tenant,
            Users.username == settings.SEED_AM_USERNAME,
        )
    ).first()
    if user is None:
        user = Users(
            tenant_id=tenant,
            username=settings.SEED_AM_USERNAME,
            password_hash=hash_password(settings.SEED_AM_PASSWORD),
            role="Area Manager",
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    # 2. AreaManagers row (links the user to a manager identity).
    manager = session.exec(
        select(AreaManagers).where(AreaManagers.user_id == user.user_id)
    ).first()
    if manager is None:
        manager = AreaManagers(user_id=user.user_id, manager_name="Pizza AM (dev)")
        session.add(manager)
        session.commit()
        session.refresh(manager)

    # 3. Brand link (scopes the AM's cluster).
    link = session.exec(
        select(AreaManagerBrands).where(
            AreaManagerBrands.manager_id == manager.manager_id,
            AreaManagerBrands.brand_id == brand.brand_id,
        )
    ).first()
    if link is None:
        session.add(
            AreaManagerBrands(
                manager_id=manager.manager_id, brand_id=brand.brand_id
            )
        )
        session.commit()


# (field_key, label, enabled, required, locked, sort_order)
_EMPLOYEE_FORM_FIELDS = [
    ("payroll_id", "Payroll ID", True, True, True, 10),
    ("employee_name", "Full name", True, True, True, 20),
    ("date_of_birth", "Date of birth", True, True, True, 30),
    ("position_id", "Position", True, True, True, 40),
    ("primary_store_id", "Primary store", True, True, True, 50),
    ("email", "Email", True, True, False, 60),
    ("payrate", "Pay rate", True, True, False, 70),
    ("pay_currency", "Currency", True, True, False, 80),
    ("phone_number", "Phone", True, False, False, 90),
    ("mag_code", "MAG card", True, False, False, 100),
    ("country_id", "Country", True, False, False, 110),
    ("additional_store_ids", "Additional stores", True, False, False, 120),
]


def _seed_form_config(session: Session, tenant: int) -> None:
    """Seed default field configuration for the employee (new-hire) form.
    Idempotent: only inserts fields that don't already exist."""
    existing = {
        c.field_key
        for c in session.exec(
            select(FormFieldConfig)
            .where(FormFieldConfig.tenant_id == tenant)
            .where(FormFieldConfig.form_key == "employee")
        ).all()
    }
    added = False
    for field_key, label, enabled, required, locked, order in _EMPLOYEE_FORM_FIELDS:
        if field_key in existing:
            continue
        session.add(
            FormFieldConfig(
                tenant_id=tenant,
                form_key="employee",
                field_key=field_key,
                label=label,
                enabled=enabled,
                required=required,
                locked=locked,
                sort_order=order,
            )
        )
        added = True
    if added:
        session.commit()


def _seed_org_data(session: Session, tenant: int) -> None:
    """Sample brand + stores + positions. Replace with real data later.
    Only runs if the tenant has no brands yet."""
    existing_brand = session.exec(
        select(Brands).where(Brands.tenant_id == tenant)
    ).first()
    if existing_brand is not None:
        return

    brand = Brands(tenant_id=tenant, brand_name="Pizza Boys")
    session.add(brand)
    session.commit()
    session.refresh(brand)

    stores = [
        Stores(tenant_id=tenant, brand_id=brand.brand_id, store_name=name)
        for name in ["Port of Spain", "San Fernando", "Chaguanas"]
    ]
    positions = [
        Positions(tenant_id=tenant, brand_id=brand.brand_id, position_title=title)
        for title in [
            "Crew Member",
            "Cashier",
            "Shift Supervisor",
            "Assistant Manager",
            "Store Manager",
        ]
    ]
    session.add_all(stores + positions)
    session.commit()
