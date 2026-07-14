from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Read from environment (docker-compose injects these). A local .env also works.
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str = "postgresql+psycopg2://staffadmin:staffpass@db:5432/staffmgmt"

    JWT_SECRET_KEY: str = "change-me-to-a-long-random-string"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 720  # 12 hours

    # First-run seeding (creates a Super Admin so you can log in immediately).
    SEED_ADMIN_USERNAME: str = "superadmin"
    SEED_ADMIN_PASSWORD: str = "ChangeMe123!"
    DEFAULT_TENANT_ID: int = 1

    # Dev-only: seed a known-credentials Area Manager over the "Pizza Boys" brand
    # so the Phase 2 cluster flows are testable end-to-end. Idempotent. Set
    # SEED_DEV_AREA_MANAGER=false in real deployments to skip it.
    SEED_DEV_AREA_MANAGER: bool = True
    SEED_AM_USERNAME: str = "am_pizza"
    SEED_AM_PASSWORD: str = "ChangeMe123!"
    SEED_AM_BRAND_NAME: str = "Pizza Boys"


settings = Settings()
