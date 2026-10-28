# Clock-in Station — client PC setup

Turn any Windows PC into a fingerprint **Clock-in Station** for the Staff Portal:
plug in the DigitalPersona U.are.U 4500, run one setup, and the station opens
full-screen ready to scan.

## What the installer does
1. **Installs the HID reader software** — the DigitalPersona driver + the
   *Authentication Device Client* (the local agent on `127.0.0.1:52181` the
   browser talks to). It runs the installers you place in `vendor\` (see below),
   or skips this if they're already installed.
2. **Creates a kiosk launcher** — opens the Clock-in Station full-screen in
   Microsoft Edge (or Chrome) at the portal's `?kiosk=1` page, with a **Desktop
   shortcut** "Clock-in Station".
3. **(Optional) Auto-start** — launches the station automatically when the PC
   signs in (`-AutoStart`).

## One-time: get the HID software
HID's installers can't be bundled here. Download them once and drop them in the
`vendor\` folder (details in `vendor\README.txt`):
- **DigitalPersona 4500 Non-WBF (Legacy) driver** — https://www.hidglobal.com/drivers/49061
- **HID Authentication Device Client** (the local agent)

If the PC already has both, you can skip the folder and pass `-SkipHid`.

## Install (on each station PC)
1. Copy this `clock-station\` folder to the PC.
2. Put the two HID installers in `clock-station\vendor\` (or skip if already installed).
3. Double-click **`Install-ClockStation.bat`** (it will ask for admin rights).
   - Default URL is the public portal's kiosk page. To point elsewhere or enable
     auto-start, run from PowerShell, e.g.:
     ```
     .\Install-ClockStation.ps1 -Url "https://YOUR-PORTAL/?kiosk=1" -AutoStart
     ```
4. Plug in the reader. Launch from the **Clock-in Station** desktop shortcut.
   Staff scan a finger to clock in/out; press **Alt+F4** to exit the kiosk.

## How it works
- The kiosk URL is the normal app with `?kiosk=1`, which skips login and goes
  straight to the scan screen (`RootGate`).
- The browser's fingerprint JS talks to the local HID agent on `localhost:52181`
  (works regardless of the page's https origin), which reads the U.are.U 4500.
- Scans are matched 1:N on the server (SourceAFIS) to identify the employee, then
  recorded as clock in/out events that fill the Attendance Register.

## Troubleshooting
- **"Fingerprint reader not detected"** in the kiosk → the agent/driver isn't
  installed or running. Re-run the setup (it checks/starts the *HID
  Authentication Device Service*), or confirm in Device Manager that the reader is
  under **Authentication Devices** with no warning.
- **Nothing happens on scan** → make sure the finger is enrolled (Admin →
  Non-Oracle Employees → the employee → Manage fingerprints).
- **Turn off dev simulate** for a real station: Admin → Settings → Clock-in →
  turn OFF "Kiosk dev / simulate mode" so only real scans can punch.
