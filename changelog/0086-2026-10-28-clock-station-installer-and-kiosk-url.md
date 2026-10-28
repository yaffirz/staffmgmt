# Changelog 0086 — Clock-in station installer + direct kiosk URL

- **Timestamp:** 2026-10-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A client-PC **installation package** so a station is "plug in the
  reader and it's running": install the HID reader software and launch the
  Clock-in Station full-screen. Plus a clean **kiosk URL** so the shortcut lands
  straight on the scan screen with no login.
- **Status:** Applied (frontend + a new `clock-station/` installer). Kiosk URL
  verified in-browser; installer validated (parses, logic reviewed).

## Direct kiosk URL
- **`screens/root_gate.dart`:** `/?kiosk=1` (or `?kiosk=true`) routes straight to
  the no-login **ClockKioskScreen**, bypassing login — captured once at startup,
  same pattern as the `?reset_token=` flow. Verified: `localhost:8000/?kiosk=1`
  opens the scan station directly.

## Installer package (`clock-station/`)
- **`Install-ClockStation.ps1`** (+ double-click **`Install-ClockStation.bat`**):
  self-elevates, then
  1. **HID software** — detects the *HID Authentication Device Service*; if
     missing, runs the driver + Authentication Device Client installers placed in
     `vendor\` (HID files are NOT redistributed — `vendor\README.txt` has the two
     download links), starting the agent if stopped.
  2. **Kiosk launcher** — writes `Launch-ClockStation.cmd` that opens the station
     full-screen in Edge (`--kiosk … --edge-kiosk-type=fullscreen`) or Chrome
     (`--kiosk`) at the `?kiosk=1` URL, with a dedicated browser profile, and a
     **Desktop shortcut**.
  3. **`-AutoStart`** optionally adds a Startup shortcut (launch at logon).
  - Params: `-Url` (default the public portal's kiosk page), `-VendorDir`,
    `-SkipHid`.
- **`README.md`** — step-by-step; **`vendor/README.txt`** — the HID downloads.

## Notes
- The HID agent listens on `localhost:52181` regardless of the page's https
  origin, so the kiosk works against the deployed portal.
- For a real station, turn OFF **Settings → Clock-in → Kiosk dev/simulate mode**
  so only real scans punch.

## Rollback
- Remove the `_kiosk` handling in `root_gate.dart` and delete `clock-station/` +
  this changelog.
