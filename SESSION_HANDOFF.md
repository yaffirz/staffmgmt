# Session Handoff — Staff Portal (staffmgmt)

**Purpose:** hand this to a new chat so it can continue seamlessly. This is a
*continuation log*, not the operating rules — those live in **`CLAUDE.md`** (read
that too). Full per-change detail is in **`changelog/0001`–`0028`**. Feature/role
reference for end users is in **`docs/USER_GUIDE.md`**; Android build steps in
**`docs/BUILD_APK.md`**.

_Last updated: 2026-07-16 (AST). Everything below is committed and pushed._

---

## 1. Current status — everything is DONE, committed, and on GitHub

- **Repo:** https://github.com/yaffirz/staffmgmt · branch **`main`** · tip **`40624d1`**.
- Git auth is cached — a plain `git push` works. `.env` is gitignored (secrets stay local).
- The full roadmap the owner set out this session is **built and verified** (one item
  verified by curl+analyze only — see §7).

### Commits on `main` (newest first)
```
40624d1  Build as Android APK: web-only bulk I/O split + manifest permissions
4bad6a1  docs: user guide (features & roles) + Android APK build guide
aade14d  Housekeeping: remove deprecated frontend/, refresh CLAUDE.md
72a85e1  Admin mini-console: audit-log viewer (standing rule #3)
42b6cfa  Trigger #1: marking reviewed notifies the brand's Area Manager(s)
5e5f37b  Cross-store assignments (finishes Phase 2b, trigger #2)
736fec8  Phase 3: staff status changes (promote/demote/terminate)
5b3ea40  IT role + multi-role users (Super-Admin-assigned)
85d2694  Phase 2b My Cluster UI + staff notes with per-note visibility
da0be5e  Initial commit: staffmgmt baseline through changelog 0014
```

---

## 2. What the project is

Internal staff-management app for a multi-brand restaurant group (Trinidad). Tracks
employees across **brands → stores → positions** with role-based access and a full
audit trail. **Backend:** FastAPI + SQLModel + PostgreSQL (Docker). **Frontend:**
Flutter (web **and** Android from one codebase).

- **Root:** `C:\Projects\staffmgmt`
- **Backend:** `backend/` (Docker; API on :8000)
- **Frontend:** `staff_frontend/` — the ONLY canonical frontend (the old `frontend/`
  folder was deleted this session).

---

## 3. How to run (dev)

- **Both at once:** double-click **`start-dev.bat`** at the root (opens two terminals).
- **Backend:** from root → `docker compose up -d` (API http://localhost:8000, health
  `/health`, docs `/docs`). Source is volume-mounted with `--reload`; **new backend
  code needs `docker compose restart backend`** to reload (and to run migrations).
- **Frontend:** from `staff_frontend/` →
  `flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8000`
  then open http://localhost:5000.
- **DB shell:** `docker compose exec db psql -U staffadmin -d staffmgmt -c "..."`
- **Verify before delivering:** backend `python -m compileall`; frontend `flutter analyze`.

### Frontend restart rule (important)
`flutter run` does **not** auto-reload on file save. **New files** require a **FULL
restart** (Ctrl+C + re-run), not a hot restart (`R`). A hot restart with new files
wedges the DWDS debug client (see §8).

---

## 4. Test accounts (dev DB) — all password `ChangeMe123!` unless noted

| Username | Role(s) | Notes |
|---|---|---|
| `superadmin` | Super Admin | Seeded (`SEED_ADMIN_*`). |
| `am_pizza` | Area Manager | **Dev seed** (changelog 0003), covers **Pizza Boys**. Use this to test AM flows. |
| `hr_test` | HR **+ IT** | Test user; multi-role. Authored notes on emp "1234". |
| `it_test` | IT | Test user (admin-lite). Receives the IT notifications. |
| `admin_test` | Admin | Test user. |
| `Nadiya` | Area Manager | Pre-existing; covers Rituals Coffee House (1 store, empty). **Password unknown.** |
| `Davindra` | Admin | Pre-existing. **Password unknown.** |

Toggles are both **on**: `area_managers_can_move=true`, `staff_notes_enabled=true`.

### Test-data side effects on the dev DB (harmless; from verification)
- Employee **"1234"** (id 3, Pizza Boys): demoted to Cashier, terminated→reactivated,
  primary store = Chaguanas, marked reviewed, has 2 notes (HR-shared + brand-shared,
  authored by am_pizza).
- Employee **"Test UI 2"** (id 2): additional store Chaguanas, marked reviewed.
- Several notifications exist. Only 4 employees total (mostly placeholder test rows).

---

## 5. What was built this session (by feature → changelog)

1. **Notifications inbox + bell** (0005–0009, 0011, 0012, 0019) — `notifications` +
   per-user `notification_reads`; topbar bell (MenuAnchor dropdown), unread badge,
   mark read / mark-all, click-through deep-links. Several render fixes (see §6).
2. **Store drilldown** (0013, 0014) — `GET /api/v1/stores/{id}/staff`; a selectable
   table; notifications deep-link into it.
3. **Phase 2b — My Cluster** (0004 backend, 0015 UI) — AM store cards; **Move**
   (change primary store) + **Request** (name search → queued to admins); admin
   **"Area Managers can move staff"** toggle.
4. **Staff notes** (0016–0019) — per-note visibility (**Private** = author+Super Admin,
   or share by **role**/**brand**); individual **staff page**; **all-notes feed** (the
   "Staff Notes" tile); `staff_notes_enabled` toggle.
5. **IT role + multi-role** (0020) — see §6 for the model.
6. **Phase 3 — status changes** (0021) — promote/demote (position), terminate/reactivate
   (`employment_status`) → `staff_status_log`; staff-page **Employment** section +
   **Status Changes** feed.
7. **Cross-store assignments** (0022, 0023) — AM adds an **additional** store to a
   cluster staffer (accumulative); wired the AM tile.
8. **Admin mini-console** (0025) — `GET /api/v1/audit-logs` + **Audit Logs** screen.
9. **Housekeeping + docs** (0026, 0027) — removed deprecated `frontend/`, refreshed
   `CLAUDE.md`, wrote the user + APK guides.
10. **Android APK** (0028) — made it build for Android (see §9).

### The 5 notification triggers (ALL LIVE)
| # | Trigger | Recipient | Type |
|---|---|---|---|
| 1 | Employee **marked reviewed** (false→true) | **AM(s)** of that brand | `STAFF_REVIEWED` — "check them in ~1h" |
| 2 | AM **assigns** staffer to another store | **IT** | `STAFF_ASSIGNED` |
| 3 | **Promoted** | **IT** | `STAFF_PROMOTED` |
| 4 | **Demoted** | **IT** | `STAFF_DEMOTED` |
| 5 | **Terminated** | **IT** | `STAFF_TERMINATED` |
Plus: AM **Move**→Admins (`STAFF_MOVED`), AM **Request**→Admins (`STAFF_REQUESTED`),
`STAFF_REACTIVATED`→IT.

---

## 6. Key architecture & decisions made this session

- **Multi-role:** `users.role` stays the single **primary** role (CHECK now includes
  `IT`). Additional roles live in a new **`user_roles`** junction; **effective roles =
  primary ∪ additional**. JWT carries a `roles` claim; `CurrentUser.has_role(*roles)`;
  `require_roles(...)` checks **intersection**. **Only Super Admin** may grant additional
  roles. Old tokens fall back to `[role]` (no forced logout). IT is "admin-lite" (in
  `WRITE_ROLES`/`STAFF_ROLES`/store view; NOT users/settings/org/delete).
- **Note visibility rule:** a user sees a note if author, Super Admin, their role ∈
  `visibility_roles`, or they're an AM of a brand ∈ `visibility_brand_ids`.
- **Cross-store is additive:** stores accumulate; a staffer is removed from a store only
  on **termination**.
- **Trigger #1 has NO scheduler:** the reframed design fires an *immediate* notification
  whose *text* says "in about an hour" — this deliberately avoided building any
  background-job infrastructure.
- **Migrations:** non-destructive, idempotent, in `backend/app/core/database.py`
  `_run_migrations()` (runs after `create_all` on startup): `staff_notes` visibility
  JSONB cols, `users` role CHECK (+IT, drop/recreate), `employees.employment_status`.
  New **tables** come from `create_all`.
- **Notification targeting:** `recipient_user_id` OR `recipient_role`; per-user read via
  `notification_reads`; Super Admin also sees Admin-targeted.

### Flutter `MenuAnchor` landmines (the bell) — all fixed, don't reintroduce
- **Don't rebuild the anchor while the menu is open** → it closes. The unread count is a
  `ValueNotifier` + `ValueListenableBuilder` so it never rebuilds `MenuAnchor`.
- **No `ListView` inside a menu** — the menu measures intrinsic height, which
  scrollables don't support ("Cannot hit test a render box that has never been laid
  out"). The panel uses a **capped `Column`** (max 6 items + "N more").
- **Hidden `Badge` (`isLabelVisible:false`) throws every frame** — render a **bare
  IconButton** when count is 0.

---

## 7. Verification status

Verified in-browser end-to-end: notifications bell, My Cluster + Move/Request,
cross-store, staff notes + visibility + feed, IT/multi-role dashboards + Users&Roles
picker, Phase 3 status changes + feed + IT notifications, trigger #1 render +
click-through.

**Not visually confirmed (tooling only):** the **Audit Logs** screen — backend
curl-verified, `flutter analyze` clean, app confirmed running, model↔schema exact.
The in-app browser's screenshot capture was wedged by the DWDS glitch (§8); the code
is sound. Worth an eyeball on a fresh full restart.

---

## 8. Environment gotchas learned this session

- **DWDS / hot-restart:** hot-restarting with **new files** leaves the Flutter web debug
  client (`dwds`) wedged — symptoms: "disposed EngineFlutterView", screenshots hang.
  Fix: **full** restart, and a browser **refresh** clears the tab state.
- **LF→CRLF** git warnings on Windows are harmless.
- The dev backend is reachable on the LAN at **`http://172.20.0.28:8000`** (this PC's
  Ethernet IP; DHCP — may change). Firewall must allow inbound **8000** for a phone.

---

## 9. The Android APK

- **Built:** `staff_frontend/build/app/outputs/flutter-apk/app-release.apk` (~51 MB).
  It's a build artifact (`build/` gitignored) — not committed.
- **Toolchain:** Android SDK at `C:\Users\admin.aa\AppData\Local\Android\Sdk`;
  `flutter config --android-sdk` already points there; licenses accepted;
  `flutter doctor` Android toolchain = green.
- **Build cmd:** `flutter build apk --release` (from `staff_frontend/`). No baked URL —
  the app's login **"Change"** screen sets the server on the device.
- **Fixes that made it build (0028):** bulk-upload's `dart:html` moved behind a
  conditional import (`services/bulk_io.dart` → `bulk_io_web.dart` on web,
  `bulk_io_stub.dart` on native); `AndroidManifest.xml` gained the **INTERNET
  permission** (release builds need it) + `usesCleartextTraffic` (for `http://`).
- **On the phone:** set server to `http://172.20.0.28:8000` (same Wi-Fi + firewall
  open), log in as `superadmin`/`ChangeMe123!`.
- **Before a production release:** real application id (off `com.example.staff_frontend`),
  app icon, **signing keystore**, HTTPS backend (then remove `usesCleartextTraffic`).
  Details in `docs/BUILD_APK.md` §6.

---

## 10. Optional follow-ups (nothing required)

Also listed in `CLAUDE.md` → "Next planned work":
- Hide/filter **terminated** staff from active rosters (currently shown with a badge).
- Retire/relabel the dead admin **"Notifications"** dashboard tile (the bell supersedes it).
- **Tenant-scope** `audit_logs` before going multi-tenant (Phase 1 is single-tenant, id 1).
- APK production hardening (§9).
- Optionally clean up the dev test users/data (§4) once no longer needed.

---

## 11. Working conventions (recap from CLAUDE.md)

- **Changelog every change:** new `changelog/NNNN-YYYY-MM-DD-short-title.md`, never edit
  prior ones; read the latest before changing anything.
- **Non-destructive DB migrations** only (`ADD COLUMN IF NOT EXISTS`, etc.; never `down -v`).
- Dates display MM/DD/YYYY; wire YYYY-MM-DD. `tenant_id` from JWT. Footer "Created by
  Arif Asad Ali".
- Toggleable features get an admin control (Settings screen).
