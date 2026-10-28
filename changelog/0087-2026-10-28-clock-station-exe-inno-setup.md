# Changelog 0087 — Clock-in station packaged as a single .exe (Inno Setup)

- **Timestamp:** 2026-10-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Package the clock-in station installer (changelog 0086) as a single
  distributable **.exe** using Inno Setup.
- **Status:** Applied + built. `ClockInStationSetup.exe` (~2 MB) compiled cleanly.

## Changes
- **`clock-station/ClockInStation.iss`** — Inno Setup 6 script. Installs the
  helper files to Program Files, optionally bundles the HID installers placed in
  `vendor\` at build time (`skipifsourcedoesntexist`), shows a wizard page for the
  **station URL** and an **auto-start at sign-in** task, then runs
  `Install-ClockStation.ps1 -NoPause -Url <…> [-AutoStart]` (elevated) to install
  the HID agent + create the full-screen kiosk launcher + Desktop/Startup shortcut.
- **`clock-station/build.bat`** — finds ISCC.exe and compiles the .iss →
  `dist\ClockInStationSetup.exe`.
- **`Install-ClockStation.ps1`** — added `-NoPause` (skip the final "Press Enter",
  for silent/Inno runs); the kiosk browser profile now uses a runtime
  `%LOCALAPPDATA%` path (resolves per launching user). Elevation relaunch passes
  the new flags through.
- **README** updated with the .exe path + build steps.
- `.gitignore`: `clock-station/dist/` (build output not committed).

## Build
- `cd clock-station && build.bat` (needs Inno Setup 6; `winget install -e --id
  JRSoftware.InnoSetup`). Drop HID installers in `vendor\` first to bundle them.

## Rollback
- Delete `ClockInStation.iss` + `build.bat`; revert the PS1 `-NoPause`/profile
  tweaks; delete this changelog.
