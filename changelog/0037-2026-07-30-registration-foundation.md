# Changelog 0037 — Self-service registration foundation (email stubbed)

- **Timestamp:** 2026-07-30 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Public sign-up → email confirmation → admin approval before an
  account is real. Email *sending* is stubbed for now (owner will configure the
  sending domain later); the whole flow is built and pluggable.
- **Status:** Applied; verified end-to-end via API; `flutter analyze` clean.

## Design
- Separate `registration_requests` table so existing login/accounts are
  untouched; an approved request is what creates the real `Users` row. Admin
  approval activates (email-confirm built but non-blocking for now). Gated by a
  `registration_enabled` setting (**default off** — public site + no email yet).

## Backend
- `models.py`: `RegistrationRequests` (username, email, password_hash, status
  `pending_email|pending_approval|approved|rejected`, email_token, email_verified,
  note, reviewed_by).
- `core/email.py`: `send_email()` stub — logs the message (incl. confirm link);
  the single place to wire SMTP later.
- `routes/registration.py`:
  - `GET /register/enabled` (public) — for the login link.
  - `POST /register` (public, gated) — creates a pending request + token; neutral
    response (no account enumeration); dedupes vs users + open requests.
  - `GET /register/confirm?token=` (public) — verifies email → `pending_approval`;
    returns a small branded HTML page.
  - `GET /registrations` (Admin) — queue with status + confirm link.
  - `POST /registrations/{id}/approve` (Admin) — `{role, store_id?, brand_ids?}`;
    creates the Users row (reuses AM/Store link helpers), assigns the role.
  - `POST /registrations/{id}/reject` (Admin).
- `app_settings.py`: `registration_enabled` default `"false"`. `main.py` wires the
  router.

## Frontend
- `register_screen.dart` (public form) + a **"Create an account"** link on
  `login_screen.dart`, shown only when `registration_enabled` (public check).
- `registrations_screen.dart` (admin queue): confirm-email (while sending is
  stubbed), approve with role + store/brands, reject; status chips. Dashboard gets
  a **"Registrations"** tile (Admin/Super Admin). Settings gets the
  self-registration toggle. Model/service added
  (`registration_request.dart`, `staff_service.dart`).

## Verification (API)
- Disabled → `/register` 403. Enabled → register (neutral msg) → listed as
  `pending_email` → confirm link → `pending_approval`/verified → approve as HR →
  user created → **new account logs in**. Toggled back off.

## Notes / next
- Email is a **no-op stub** (logs only). To go live: wire SMTP in `core/email.py`
  once the sending domain (SPF/DKIM) is set up; optionally add a
  `require_email_confirmation` setting to make confirmation blocking.

## Deployment
- Built: web rebuilt. Live via tunnel. Prod: yes (toggle off by default).

## Rollback
- Revert edits; drop `registration_requests` + `routes/registration.py` +
  `core/email.py` + the `registration_enabled` setting.
