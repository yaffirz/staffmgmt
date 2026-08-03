# Changelog 0040 — In-app Android APK download (login-gated)

- **Timestamp:** 2026-07-31 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Let signed-in users download the latest Android app from the web app,
  so staff can install/update it without the Play Store.
- **Status:** Applied; verified end-to-end locally and through the tunnel;
  `flutter analyze` clean; web rebuilt; backend recreated for the new mount.

## Design
- **Login-gated:** both endpoints require a valid token (any role). The installer
  holds no secrets (server URL is set in-app), but access is limited to staff.
- The backend only **serves** whatever APK is published to `APP_DIST_DIR`; the
  APK is a build artifact (gitignored), published to `./public` on the host.

## Backend
- `schemas/app_dist.py`, `routes/app_dist.py`:
  - `GET /api/v1/app/info` — `{enabled, available, filename, size_bytes,
    updated_at}` (available = toggle on AND an APK exists).
  - `GET /api/v1/app/download` — `FileResponse` of `app-release.apk`
    (`application/vnd.android.package-archive`).
- `app_settings.py`: `app_download_enabled` default `"true"`. Registered in
  `main.py`.
- `docker-compose.yml`: `APP_DIST_DIR=/code/public` + read-only mount
  `./public:/code/public:ro`. `.gitignore`: `/public/`.
- `scripts/publish-apk.sh`: copies the built APK into `./public` (publish step).

## Frontend
- `models/app_info.dart`; `staff_service` `appInfo()` / `downloadApk()` (raw bytes
  via `api_client.getBytes`).
- `widgets/app_download_banner.dart`: a "Get the Android app" card on the
  dashboard — **web only** (`downloadSupported`) and only when available; fetches
  the APK bytes and triggers a browser save (reuses `services/file_download`).
  Shows updated date + size + an "unknown sources" hint.
- `settings_screen.dart`: an **Android app** toggle (`app_download_enabled`).

## Publishing a new build
```
(cd staff_frontend && flutter build apk --release)
scripts/publish-apk.sh        # copies it to ./public
```
No restart needed — the backend serves the new file immediately.

## Verification
- Unauthenticated `/app/info` + `/app/download` → 403. Signed-in → info shows
  available + size + date; download returns the 52 MB APK
  (`application/vnd.android.package-archive`, starts with `PK`). Confirmed through
  `https://gbgstaff.atmix.io` too.

## Deployment
- Built: web rebuilt; backend recreated (new mount). APK published to `./public`.
  Live via tunnel.

## Rollback
- Revert edits; drop `routes/app_dist.py`, the mount/env, and the
  `app_download_enabled` setting.
