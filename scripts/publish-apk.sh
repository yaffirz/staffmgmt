#!/usr/bin/env bash
# Publish the built Android APK so signed-in users can download it from the web
# app (served read-only from ./public by the backend). Run after:
#   (cd staff_frontend && flutter build apk --release)
set -e
cd "$(dirname "$0")/.."
SRC="staff_frontend/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$SRC" ]; then
  echo "APK not found. Build it first:"
  echo "  (cd staff_frontend && flutter build apk --release)"
  exit 1
fi
mkdir -p public
cp "$SRC" public/app-release.apk
echo "Published $(du -h public/app-release.apk | cut -f1) to ./public/app-release.apk"
echo "Signed-in users will see it on the dashboard (if the Settings toggle is on)."
