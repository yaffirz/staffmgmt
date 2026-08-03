"""App distribution: serve the published Android APK to signed-in users.

Login-gated (any authenticated user) — the installer holds no secrets, but access
is limited to logged-in staff. The APK is published to APP_DIST_DIR on the host
(see docs); this only serves whatever file is there.
"""
import os
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlmodel import Session

from app.api.deps import get_current_user
from app.core.app_settings import get_bool
from app.core.database import get_session
from app.schemas.app_dist import AppInfo
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1/app", tags=["app-dist"])

APP_DIST_DIR = os.getenv("APP_DIST_DIR", "/code/public")
APK_NAME = "app-release.apk"


def _apk_path() -> str:
    return os.path.join(APP_DIST_DIR, APK_NAME)


@router.get("/info", response_model=AppInfo)
def app_info(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Whether an Android build is available to download (any signed-in user)."""
    enabled = get_bool(session, current.tenant_id, "app_download_enabled", True)
    path = _apk_path()
    if not enabled or not os.path.isfile(path):
        return AppInfo(enabled=enabled, available=False)
    st = os.stat(path)
    return AppInfo(
        enabled=enabled,
        available=True,
        filename=APK_NAME,
        size_bytes=st.st_size,
        updated_at=datetime.fromtimestamp(st.st_mtime, tz=timezone.utc),
    )


@router.get("/download")
def download_app(
    current: CurrentUser = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Download the published APK (any signed-in user)."""
    if not get_bool(session, current.tenant_id, "app_download_enabled", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="App download is disabled.",
        )
    path = _apk_path()
    if not os.path.isfile(path):
        raise HTTPException(status_code=404, detail="No app build is available.")
    return FileResponse(
        path,
        media_type="application/vnd.android.package-archive",
        filename=APK_NAME,
    )
