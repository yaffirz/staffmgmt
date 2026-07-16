# Changelog 0028 — Make the app build as an Android APK

- **Timestamp:** 2026-07-16 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Produce an installable Android APK.
- **Status:** Applied; **APK built successfully** (`app-release.apk`, ~51 MB) at
  `staff_frontend/build/app/outputs/flutter-apk/`.

## Problem
A release `flutter build apk` failed at the Dart AOT compile because the bulk-upload
screen used **`dart:html`** (browser download + file picker) — web-only APIs that
can't compile for Android. `flutter run` / `flutter analyze` don't catch this (only a
release AOT compile is that strict). Also, a release APK lacked the **INTERNET
permission** (Flutter only adds it to the debug manifest by default).

## Fix
- **Cross-platform bulk-CSV I/O via conditional import:**
  - `services/bulk_io.dart` — `export 'bulk_io_stub.dart' if (dart.library.html)
    'bulk_io_web.dart';`
  - `services/bulk_io_web.dart` — the existing `dart:html` download/upload (web).
  - `services/bulk_io_stub.dart` — no-op for native (Android/iOS/desktop).
  - `screens/bulk_upload_screen.dart` — uses `bulk_io` instead of `dart:html`;
    the Download-template and Choose-file buttons are hidden when
    `bulk_io.bulkFileIoSupported` is false (native). Paste + copy still work, so
    bulk import remains usable on mobile.
- **AndroidManifest.xml:** added `<uses-permission android:name="android.permission.INTERNET"/>`
  (needed by release builds) and `android:usesCleartextTraffic="true"`
  (so the app can reach an `http://` backend; remove for https-only production).

## Result
- Web build: unchanged (full bulk import).
- `flutter build apk --release` → succeeds; APK ~51 MB. Server URL is set in-app
  via the login "Change" screen (no baked URL).
- `flutter analyze` clean apart from expected `dart:html`-in-web-file info lints.

## Files touched
- staff_frontend/lib/services/bulk_io.dart, bulk_io_web.dart, bulk_io_stub.dart (new)
- staff_frontend/lib/screens/bulk_upload_screen.dart
- staff_frontend/android/app/src/main/AndroidManifest.xml

## Notes
- The `.apk` is a build artifact under `build/` (gitignored) — not committed.
- Before a store/production release: real application id, signing keystore, HTTPS
  backend (remove cleartext). See docs/BUILD_APK.md.

## Deployment
- Built: Android APK (local). Deployed to production: no.

## Rollback
- Revert the edits; the bulk_io split can also just be deleted (restore dart:html).
