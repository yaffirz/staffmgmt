# Changelog 0081 — Real fingerprint capture + SourceAFIS matcher + "Test a scan"

- **Timestamp:** 2026-10-27 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Make fingerprints real on the DigitalPersona U.are.U 4500: capture live
  scans during enrolment, and add a button to **test** a registered fingerprint
  (verify a fresh scan matches the enrolment). Also fixes the Non-Oracle employee
  list, whose row actions were un-clickable.
- **Status:** Applied (frontend + backend + a new matcher service). Capture verified
  live in-app; matcher verified on the real captured PNG (self-match score 408 ≥ 40).

## Fingerprint capture (DigitalPersona Web SDK)
- Vendored the MIT **DigitalPersona JS SDK** into `staff_frontend/web/dp/`
  (`websdk.client.js` + `@digitalpersona/{core,services,devices}` UMD) and a small
  bridge `dp_fingerprint.js` (`window.dpFingerprint`: `isAvailable/enumerate/
  capture/cancel`, capturing **PngImage**). Loaded by `web/index.html`.
- Dart interop `services/dp_fingerprint*.dart` (conditional import, APK-safe; web
  uses `dart:js_interop`). The Non-Oracle **Manage fingerprints** dialog now
  captures a live scan on **Register / Re-scan** (`_CaptureDialog`), storing the
  real template; falls back to a dev placeholder when no reader is present.
- The reader needs HID's **Authentication Device Client** (local agent, port
  52181) + the **Non-WBF (Legacy)** driver. No HID dev-portal licence required —
  the JS SDK is open-source. See `docs/FINGERPRINT.md`.

## Matcher service (SourceAFIS via nodeafis)
- New **`matcher/`** microservice (Node, `nodeafis` = pure-TS SourceAFIS port +
  `pngjs`). `POST /verify {probe, candidates[]}` → `{score, bestIndex, match,
  threshold}`. Decodes the reader's **palette PNG** with pngjs → grayscale →
  `FingerprintImage.fromRaw` (500 DPI); threshold **40** (~0.01% FMR). Added to
  `docker-compose.yml` as an internal service (`http://matcher:9000`); backend
  gets `MATCHER_URL` (`core/config.py`). **Build with `docker compose build
  matcher`** (installs + compiles nodeafis).
- Backend `POST /api/v1/fingerprints/verify {employee_id, sample}` (Super Admin /
  Admin / IT) flattens the employee's stored PNG samples, calls the matcher, and
  returns `{match, score, threshold, finger_label, enrolled_samples}`.
- Frontend: a **"Test a scan"** button in the fingerprints dialog (shown once a
  finger is enrolled) captures a scan and shows **Match ✓ (finger, score)** or
  **No match**.
- This matcher is also the engine the kiosk's "who is this?" identify will use
  (next phase).

## Non-Oracle list: un-clickable rows fixed
- The employees view was a `PaginatedDataTable` nested in horizontal+vertical
  `SingleChildScrollView`s — a Flutter-web combo that **swallows all taps** on the
  cells (the ⋮ menu, links and buttons were dead). Replaced with a **tappable card
  list** (`InkWell`); tapping a card (or its ⋮) opens a bottom sheet with Manage
  fingerprints / Remove / Reset. Confirmed working.

## Verification
- **Capture:** enrolled a live scan in-app against a test employee — a 189 KB
  PngImage template stored (`{"fmt":"PngImage","samples":["iVBOR…`).
- **Matcher:** self-match of the stored PNG → score **408.5**, `match:true`; full
  `/verify` endpoint (auth + candidate load + matcher) returns the match with the
  correct `finger_label`. Matcher reachable from the backend (`/health` ok).
- `flutter analyze` clean; `flutter build web` ok; backend `compileall` ok;
  `docker compose build matcher` ok.

## Next
- Wire the kiosk identify (1:N) to the matcher so a walk-up scan clocks the right
  person in. Optionally cache extracted templates for speed.

## Rollback
- Remove the `matcher` service + `web/dp/` + the dp_fingerprint Dart/JS + the
  verify endpoint + Test button; revert the card list; delete this changelog.
