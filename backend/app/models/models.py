from datetime import date, datetime, timezone
from typing import Optional

from sqlalchemy import CheckConstraint, Column, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlmodel import Field, SQLModel

ALLOWED_ROLES = (
    "Super Admin",
    "Admin",
    "HR",
    "Area Manager",
    "IT",
    "Store",
    "Foodmall",
)
ALLOWED_STATUS_ACTIONS = (
    "PROMOTION",
    "DEMOTION",
    "TERMINATION",
    "REACTIVATION",
    "TRANSFER",
)
ALLOWED_AUDIT_ACTIONS = ("INSERT", "UPDATE", "DELETE")


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# A. Organization Hierarchy
# ---------------------------------------------------------------------------
class Brands(SQLModel, table=True):
    __tablename__ = "brands"

    brand_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    brand_name: str


class Stores(SQLModel, table=True):
    __tablename__ = "stores"

    store_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    brand_id: int = Field(foreign_key="brands.brand_id")
    store_name: str
    # A foodmall store carries multiple brands (its primary brand_id plus the
    # extra brands in `store_brands`). Added via non-destructive migration.
    is_foodmall: bool = Field(default=False)


class StoreBrands(SQLModel, table=True):
    """Extra brands a foodmall store carries, beyond its primary `stores.brand_id`.
    A store's effective brands = {brand_id} ∪ these."""

    __tablename__ = "store_brands"
    __table_args__ = (
        UniqueConstraint("store_id", "brand_id", name="uq_storebrands_store_brand"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    store_id: int = Field(foreign_key="stores.store_id")
    brand_id: int = Field(foreign_key="brands.brand_id")


class StoreUsers(SQLModel, table=True):
    """Links a Store/Foodmall account to the single store it manages."""

    __tablename__ = "store_users"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_storeusers_user"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.user_id")
    store_id: int = Field(foreign_key="stores.store_id")


class Positions(SQLModel, table=True):
    __tablename__ = "positions"

    position_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    # A brand-specific job role, OR a UNIVERSAL role when brand_id is NULL —
    # available to every brand except those opted out via position_brand_optouts.
    brand_id: Optional[int] = Field(default=None, foreign_key="brands.brand_id")
    position_title: str


class PositionBrandOptOuts(SQLModel, table=True):
    """A universal position (positions.brand_id IS NULL) switched OFF for a
    specific brand. Absence of a row = that brand can use the universal role."""

    __tablename__ = "position_brand_optouts"
    __table_args__ = (
        UniqueConstraint(
            "position_id", "brand_id", name="uq_posoptout_position_brand"
        ),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    position_id: int = Field(foreign_key="positions.position_id", index=True)
    brand_id: int = Field(foreign_key="brands.brand_id", index=True)


class Countries(SQLModel, table=True):
    __tablename__ = "countries"

    country_id: Optional[int] = Field(default=None, primary_key=True)
    country_name: str = Field(default="Trinidad")


# ---------------------------------------------------------------------------
# B. Core Staff & Management
# ---------------------------------------------------------------------------
class Users(SQLModel, table=True):
    __tablename__ = "users"
    __table_args__ = (
        # FIX: username is unique *within a tenant*, not globally — so two
        # tenants can each have their own "admin" account.
        UniqueConstraint("tenant_id", "username", name="uq_users_tenant_username"),
        UniqueConstraint("tenant_id", "email", name="uq_users_tenant_email"),
        CheckConstraint(
            "role IN ('Super Admin', 'Admin', 'HR', 'Area Manager', 'IT', "
            "'Store', 'Foodmall')",
            name="ck_users_role",
        ),
    )

    user_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    username: str = Field(index=True)
    email: Optional[str] = Field(default=None)
    password_hash: str
    role: str
    # When true, the user must set a new password before using the app (enforced
    # at login). Cleared once they change it. Added via non-destructive migration.
    must_change_password: bool = Field(default=False)
    # When true, the account is suspended: it cannot log in and any live session
    # is rejected on its next request. Reversible. Non-destructive migration.
    suspended: bool = Field(default=False)


class UserRoles(SQLModel, table=True):
    """Additional roles beyond a user's primary `users.role`. Effective roles =
    {primary} ∪ {these}. Only a Super Admin may grant additional roles."""

    __tablename__ = "user_roles"
    __table_args__ = (
        UniqueConstraint("user_id", "role", name="uq_user_roles_user_role"),
    )

    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.user_id")
    role: str


class AreaManagerBrands(SQLModel, table=True):
    __tablename__ = "area_manager_brands"
    __table_args__ = (
        UniqueConstraint("manager_id", "brand_id", name="uq_amb_manager_brand"),
    )

    amb_id: Optional[int] = Field(default=None, primary_key=True)
    manager_id: int = Field(foreign_key="area_managers.manager_id")
    brand_id: int = Field(foreign_key="brands.brand_id")


class AreaManagers(SQLModel, table=True):
    __tablename__ = "area_managers"

    manager_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="users.user_id")
    manager_name: str


class AreaManagerStores(SQLModel, table=True):
    __tablename__ = "area_manager_stores"
    __table_args__ = (
        UniqueConstraint("manager_id", "store_id", name="uq_ams_manager_store"),
    )

    ams_id: Optional[int] = Field(default=None, primary_key=True)
    manager_id: int = Field(foreign_key="area_managers.manager_id")
    store_id: int = Field(foreign_key="stores.store_id")


class Employees(SQLModel, table=True):
    __tablename__ = "employees"
    __table_args__ = (
        # FIX: payroll_id / email unique *per tenant* (composite), not globally.
        # Postgres treats NULLs as distinct, so many employees may have NULL email.
        UniqueConstraint("tenant_id", "payroll_id", name="uq_employees_tenant_payroll"),
        UniqueConstraint("tenant_id", "email", name="uq_employees_tenant_email"),
    )

    employee_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    payroll_id: str
    employee_name: str
    date_of_birth: date
    phone_number: Optional[str] = Field(default=None)
    email: Optional[str] = Field(default=None)
    # True = email deliberately not provided at hire ("email unavailable");
    # flags the row for HR to supply one later. Cleared once an email is set.
    email_pending: bool = Field(default=False)
    payrate: Optional[float] = Field(default=None)
    pay_currency: Optional[str] = Field(default=None)
    mag_code: Optional[str] = Field(default=None)
    country_id: Optional[int] = Field(default=None, foreign_key="countries.country_id")
    primary_store_id: Optional[int] = Field(default=None, foreign_key="stores.store_id")
    position_id: Optional[int] = Field(default=None, foreign_key="positions.position_id")
    # The brand the staffer belongs to. Normally equals the primary store's brand,
    # but a foodmall store carries several brands, so this records which one they
    # were hired under. NULL (older rows) falls back to the store's primary brand.
    brand_id: Optional[int] = Field(default=None, foreign_key="brands.brand_id")
    reviewed: bool = Field(default=False, index=True)
    # 'active' | 'terminated'. Added via non-destructive migration.
    employment_status: str = Field(default="active")
    created_at: datetime = Field(default_factory=utcnow)
    # Who created the record (the signed-in user at add/import time) and when the
    # row was last marked reviewed. Both nullable — historical rows predate them.
    # Added via non-destructive migration.
    created_by: Optional[int] = Field(default=None, foreign_key="users.user_id")
    reviewed_at: Optional[datetime] = Field(default=None)


class EmployeeAdditionalStores(SQLModel, table=True):
    __tablename__ = "employee_additional_stores"
    __table_args__ = (
        UniqueConstraint("employee_id", "store_id", name="uq_eas_employee_store"),
    )

    eas_id: Optional[int] = Field(default=None, primary_key=True)
    employee_id: int = Field(foreign_key="employees.employee_id")
    store_id: int = Field(foreign_key="stores.store_id")


# ---------------------------------------------------------------------------
# C. System History & Audit
# ---------------------------------------------------------------------------
class StaffNotes(SQLModel, table=True):
    __tablename__ = "staff_notes"

    note_id: Optional[int] = Field(default=None, primary_key=True)
    employee_id: int = Field(foreign_key="employees.employee_id")
    author_user_id: int = Field(foreign_key="users.user_id")
    note_text: str
    created_at: datetime = Field(default_factory=utcnow)
    # Per-note visibility. Empty both = private (author + Super Admin only).
    # visibility_roles: role names that may view; visibility_brand_ids: brands
    # whose Area Managers may view. Added via non-destructive migration.
    visibility_roles: list = Field(
        default_factory=list,
        sa_column=Column(
            JSONB, nullable=False, server_default=text("'[]'::jsonb")
        ),
    )
    visibility_brand_ids: list = Field(
        default_factory=list,
        sa_column=Column(
            JSONB, nullable=False, server_default=text("'[]'::jsonb")
        ),
    )


class StaffStatusLog(SQLModel, table=True):
    __tablename__ = "staff_status_log"

    log_id: Optional[int] = Field(default=None, primary_key=True)
    employee_id: int = Field(foreign_key="employees.employee_id")
    action_type: str
    details: Optional[dict] = Field(default=None, sa_column=Column(JSONB))
    processed_by: int = Field(foreign_key="users.user_id")
    timestamp: datetime = Field(default_factory=utcnow)


class AuditLogs(SQLModel, table=True):
    __tablename__ = "audit_logs"

    audit_id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int
    action: str
    affected_table: str
    record_id: str
    old_value: Optional[dict] = Field(default=None, sa_column=Column(JSONB))
    new_value: Optional[dict] = Field(default=None, sa_column=Column(JSONB))
    timestamp: datetime = Field(default_factory=utcnow)


# ---------------------------------------------------------------------------
# ADDED: Notifications — required by Step 4's "internal notification queue for
# Admins" but missing from the original blueprint.
# ---------------------------------------------------------------------------
class Notifications(SQLModel, table=True):
    __tablename__ = "notifications"

    notification_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    # Either target a broad role (e.g. "Admin") or a specific user.
    recipient_role: Optional[str] = Field(default=None)
    recipient_user_id: Optional[int] = Field(
        default=None, foreign_key="users.user_id"
    )
    type: str
    payload: Optional[dict] = Field(default=None, sa_column=Column(JSONB))
    is_read: bool = Field(default=False, index=True)
    created_at: datetime = Field(default_factory=utcnow)


class NotificationReads(SQLModel, table=True):
    """Per-user read state for notifications. A role-broadcast notification is
    shared across recipients, so read-ness is tracked per (notification, user)
    rather than as a single flag on the notification row."""

    __tablename__ = "notification_reads"
    __table_args__ = (
        UniqueConstraint(
            "notification_id", "user_id", name="uq_notifread_notif_user"
        ),
    )

    read_id: Optional[int] = Field(default=None, primary_key=True)
    notification_id: int = Field(foreign_key="notifications.notification_id")
    user_id: int = Field(foreign_key="users.user_id")
    read_at: datetime = Field(default_factory=utcnow)


class AppSettings(SQLModel, table=True):
    """Simple per-tenant key/value settings (feature toggles, etc.).
    Created non-destructively by create_all on startup."""

    __tablename__ = "app_settings"
    __table_args__ = (
        UniqueConstraint("tenant_id", "key", name="uq_appsettings_tenant_key"),
    )

    setting_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    key: str = Field(index=True)
    value: str


class RegistrationRequests(SQLModel, table=True):
    """Self-service sign-ups awaiting email confirmation + admin approval. Kept
    separate from `users` so existing login/accounts are untouched; an approved
    request is what creates the real Users row."""

    __tablename__ = "registration_requests"

    id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    username: str
    email: str
    password_hash: str
    # pending_email -> pending_approval -> approved | rejected
    status: str = Field(default="pending_email", index=True)
    email_token: str = Field(index=True)
    email_verified: bool = Field(default=False)
    note: Optional[str] = Field(default=None)
    created_at: datetime = Field(default_factory=utcnow)
    reviewed_by: Optional[int] = Field(default=None, foreign_key="users.user_id")


class Backups(SQLModel, table=True):
    """A database backup (pg_dump) — one row per run, manual or scheduled."""

    __tablename__ = "backups"

    id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    filename: str
    status: str = Field(default="running", index=True)  # running|completed|failed
    kind: str = Field(default="manual")  # manual|scheduled
    size_bytes: int = Field(default=0)
    created_by: Optional[int] = Field(default=None, foreign_key="users.user_id")
    started_at: datetime = Field(default_factory=utcnow)
    finished_at: Optional[datetime] = Field(default=None)
    error: Optional[str] = Field(default=None)


class FormFieldConfig(SQLModel, table=True):
    __tablename__ = "form_field_config"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "form_key", "field_key", name="uq_formfield_tenant_form_field"
        ),
    )

    config_id: Optional[int] = Field(default=None, primary_key=True)
    tenant_id: int = Field(default=1, index=True)
    form_key: str = Field(index=True)  # e.g. "employee"
    field_key: str  # e.g. "email", "phone_number"
    label: str
    enabled: bool = Field(default=True)
    required: bool = Field(default=False)
    # Locked = structural field; admins cannot toggle enabled/required.
    locked: bool = Field(default=False)
    sort_order: int = Field(default=0)
