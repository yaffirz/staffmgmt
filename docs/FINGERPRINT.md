# Fingerprint clock-in — setup & how it works

Hardware: **HID DigitalPersona U.are.U 4500** (USB). Used for the Non-Oracle
clock-in roster: enrol fingerprints per employee, test them, and (next phase)
identify staff at the kiosk.

No HID developer-portal licence is required — the browser SDK is open-source (MIT)
and the SourceAFIS matcher is open-source (Apache-2.0).

## On each scanning PC (Windows)
1. **Reader driver** — install HID's **DigitalPersona 4500 _Non-WBF (Legacy)_**
   driver (hidglobal.com/drivers/49061). *Not* the WBF/Hello driver — that hands
   the reader to Windows Hello and blocks the SDK. After install the device shows
   under **Device Manager → Authentication Devices** with no warning.
2. **Local agent** — install HID's **Authentication Device Client** (a.k.a.
   DigitalPersona Lite Client). It runs the **"HID Authentication Device Service"**
   (`DpHostW.exe`) listening on `127.0.0.1:52181`, which the browser talks to.

Verify both are in place: the device is under *Authentication Devices* (no ⚠) and
the service is running. The browser then reaches it with no extra config.

## How capture works (no licence)
- `staff_frontend/web/dp/` vendors the DigitalPersona JS SDK (MIT): `websdk.client.js`
  (the WebSdk client that talks to the local agent) + `@digitalpersona/{core,
  services,devices}`. `web/dp/dp_fingerprint.js` wraps it as `window.dpFingerprint`.
- `index.html` loads them; Dart calls them via `services/dp_fingerprint*.dart`
  (web-only, APK-safe). Capture format is **PNG** (`SampleFormat.PngImage`).
- Enrol / re-scan / test live in **Admin → Non-Oracle Employees → (card) → Manage
  fingerprints**. Templates are stored in the `fingerprints` table as
  `{"fmt":"PngImage","samples":[<base64 png>...]}`.

## How matching works
- The browser SDK only **captures**; matching is done by the **`matcher/`**
  microservice (SourceAFIS via `nodeafis`, + `pngjs` to decode the reader's
  palette PNG). It's internal-only (`http://matcher:9000`); the backend reaches it
  via `MATCHER_URL`.
- Backend `POST /api/v1/fingerprints/verify {employee_id, sample}` scores a fresh
  scan against the employee's stored samples. Threshold **40** ≈ 0.01% false-match
  rate (SourceAFIS guidance). The **"Test a scan"** button uses this.
- Build/run the matcher: `docker compose build matcher && docker compose up -d
  matcher` (installs + compiles nodeafis from GitHub).

## Notes
- The reader scans at **500 DPI** (nodeafis default); don't change `FP_DPI` unless
  the sensor changes.
- Production kiosks are served over the Cloudflare hostname, but the agent is
  always `localhost:52181` on the kiosk PC — the page origin doesn't matter.
- The `matcher` extracts templates on each call; for kiosk 1:N identify at scale,
  cache extracted templates (future optimisation).
