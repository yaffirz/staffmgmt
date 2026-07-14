# Staff Portal — Flutter Frontend (Step 2)

One responsive codebase for the **web portal** (desktop browser) and **mobile**
(Android/iOS). Implements the Step 2 architecture:

- **State management:** Provider (`AuthProvider`, a `ChangeNotifier`) as the single
  source of truth for auth state.
- **API client wrapper:** `ApiClient` attaches the stored JWT to every outbound
  request automatically — screens never touch headers.
- **Login + role routing:** `LoginScreen` authenticates; `RootGate` reads the
  returned role/session and routes to the role-scoped `DashboardScreen`.
- **Permanent footer:** every screen is built with `AppScaffold`, which pins the
  "Created by Arif Asad Ali" footer to the bottom of the page on web and mobile.

## Project layout

```
frontend/
├── pubspec.yaml
├── analysis_options.yaml
└── lib/
    ├── main.dart                  # wires services + provider, runs auto-login
    ├── config/app_config.dart     # API base URL + creator name
    ├── theme/app_theme.dart       # palette + Material 3 theme
    ├── models/auth_user.dart
    ├── services/
    │   ├── token_store.dart        # JWT persistence (shared_preferences)
    │   ├── api_client.dart         # HTTP wrapper, auto-attaches Bearer token
    │   └── auth_service.dart
    ├── state/auth_provider.dart    # Provider state
    ├── widgets/
    │   ├── app_footer.dart         # the permanent credit footer
    │   └── app_scaffold.dart       # wraps every page so the footer is permanent
    └── screens/
        ├── root_gate.dart          # splash / login / dashboard switch
        ├── login_screen.dart       # responsive two-pane (web) / stacked (mobile)
        └── dashboard_screen.dart   # role-aware module grid
```

## First-time setup

Flutter generates the platform folders (`web/`, `android/`, `ios/`) per machine,
so generate them, then drop these sources in:

```bash
# 1. Create a throwaway project to get the platform scaffolding
flutter create staff_frontend
cd staff_frontend

# 2. Replace its lib/ and pubspec.yaml with the ones from this folder
#    (copy frontend/lib/ over staff_frontend/lib/, and frontend/pubspec.yaml too)

# 3. Pull packages
flutter pub get
```

## Run it

Make sure the backend stack from Step 1 is up first (`docker compose up`).

**Web portal (desktop browser):**

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

**Android emulator** (the emulator reaches your host via `10.0.2.2`):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**iOS simulator:**

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

**Physical phone on your home Wi-Fi** — find your machine's LAN IP (e.g.
`192.168.1.X`) and point the app at it:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8000
```

Log in with the seeded Super Admin (`superadmin` / `ChangeMe123!` unless you
changed it in the backend `.env`).

## Notes

- The backend already sends permissive CORS headers, so the Flutter **web** build
  can call it cross-origin in development. Tighten `allow_origins` on the backend
  before production.
- A physical phone must be on the **same network** as the machine running Docker,
  and the API must be reachable at your LAN IP — not `localhost` (localhost on the
  phone is the phone itself).
- `AppConfig.apiBaseUrl` reads the `--dart-define` value, so you never edit code to
  switch targets. Without a define it defaults to `http://localhost:8000`.
