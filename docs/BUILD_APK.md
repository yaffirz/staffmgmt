# Building the Android APK

The Flutter app in `staff_frontend/` already includes the `android/` platform, so it
builds to an APK from the same code as the web app. Run all commands from
`C:\Projects\staffmgmt\staff_frontend`.

---

## 0. TL;DR

```bash
# from staff_frontend/
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.example.com
# output:
#   build/app/outputs/flutter-apk/app-release.apk
```

Install that APK on the phone (sideload) and you're running. The details below cover
the two things that actually trip people up: **the server URL** and **HTTP vs HTTPS**.

---

## 1. Prerequisites (one-time)

- **Flutter SDK** (already installed — you run `flutter run` for the web app).
- **Android toolchain:** Android Studio *or* the Android command-line SDK + a JDK.
- Verify and accept licenses:
  ```bash
  flutter doctor            # the "Android toolchain" line must be a check, not an X
  flutter doctor --android-licenses
  ```
  If `flutter doctor` flags Android, install the Android SDK (via Android Studio →
  SDK Manager) and re-run.

---

## 2. Point the app at the RIGHT backend (important)

The phone is **not** the dev machine, so `http://localhost:8000` will **not** work on a
device. Pick one:

| Situation | API_BASE_URL to use |
|---|---|
| Physical phone on the same Wi-Fi as the dev PC | `http://<PC-LAN-IP>:8000` (e.g. `http://192.168.1.20:8000`) |
| Android **emulator** on the dev PC | `http://10.0.2.2:8000` (special alias for the host) |
| Real rollout (recommended) | `https://your-deployed-backend.com` |

Two ways to set it:

- **Bake it in at build time** (simplest): add
  `--dart-define=API_BASE_URL=<url>` to the build command (see §4).
- **Set it in the app:** on the login screen tap **"Change"** and enter the server URL —
  the app stores it on the device. Good if one APK must work against different servers.

> Find your PC's LAN IP: `ipconfig` (look for the IPv4 address on your Wi-Fi adapter).
> The backend already listens on all interfaces (Docker maps `0.0.0.0:8000`), but your
> **Windows firewall** may need to allow inbound port 8000 for a phone to reach it.

---

## 3. HTTP vs HTTPS (the #1 gotcha)

Android **blocks plain `http://` traffic by default** (API 28+). So:

- **Using `https://` (a real deployed backend): nothing to do.** ✅
- **Using `http://<LAN-IP>` for testing:** you must allow cleartext, or the app will fail
  to reach the server. Easiest: edit
  `staff_frontend/android/app/src/main/AndroidManifest.xml` and add
  `android:usesCleartextTraffic="true"` to the `<application ...>` tag:
  ```xml
  <application
      android:label="staff_frontend"
      android:usesCleartextTraffic="true"
      ...>
  ```
  (Remove it again before a production build if you switch to HTTPS.)

CORS is **not** a concern for the Android app — CORS only applies to browsers, and the
native app doesn't send an `Origin` header anyway.

---

## 4. Build the APK

**Quick test build** (unsigned "debug"-style is fine for sideloading to your own devices):
```bash
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

**Release build** (smaller, optimised; still self-signed with a debug key unless you set
up signing — see §6):
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.example.com
```

**Smaller downloads** (one APK per CPU type instead of a universal one):
```bash
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://...
```

Output is written to:
```
staff_frontend/build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Install / distribute

- **Sideload:** copy the `.apk` to the phone (USB, email, cloud), tap it, and allow
  "install from unknown sources" when prompted.
- **Wireless install via USB debugging:** `flutter install` (with the phone connected and
  USB debugging on) or `adb install build/app/outputs/flutter-apk/app-release.apk`.
- **Team distribution:** use Firebase App Distribution, Diawi, or an MDM. For the **Google
  Play Store** you must set a real application id and signing (below) and upload an **App
  Bundle** instead: `flutter build appbundle --release ...`.

---

## 6. Before a real/production release

1. **Change the application id** from the Flutter default. In
   `staff_frontend/android/app/build.gradle(.kts)` set `namespace` and `applicationId`
   from `com.example.staff_frontend` to your own (e.g. `io.atmix.staffportal`).
2. **App name / icon:** the label is in `AndroidManifest.xml` (`android:label`); the icon
   is under `android/app/src/main/res/mipmap-*` (the
   [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) package
   makes this easy).
3. **Signing key (required for Play, recommended for trusted sideloading):**
   - Create a keystore:
     `keytool -genkey -v -keystore staffportal.jks -keyalg RSA -keysize 2048 -validity 10000 -alias staffportal`
   - Add a `key.properties` file and a `signingConfigs` block to
     `android/app/build.gradle` (see the Flutter docs:
     https://docs.flutter.dev/deployment/android#signing-the-app).
   - **Keep the keystore + passwords safe and out of git** (they belong in `.env`-style
     secret storage, never committed).
4. **Backend must be internet-reachable over HTTPS** for phones outside the office LAN —
   deploy it behind a domain + TLS (the web app already runs at `gbgsales`-style hosting;
   point the APK at that URL).
5. Bump `version:` in `pubspec.yaml` for each release (e.g. `0.2.0+2`).

---

## 7. Quick reachability checklist (if the app can't log in)

- [ ] Is the backend running? `curl http://<host>:8000/health` should return `{"status":"ok"}`.
- [ ] Is the phone using the correct `API_BASE_URL` (LAN IP / `10.0.2.2` / domain — **not** `localhost`)?
- [ ] If `http://`, did you enable `usesCleartextTraffic` (§3)?
- [ ] Firewall allowing inbound `8000` from the LAN?
- [ ] Phone and PC on the **same network** (for LAN testing)?
