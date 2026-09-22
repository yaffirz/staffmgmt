# Changelog 0068 — Editable email templates + signature (reusable tags)

- **Timestamp:** 2026-09-22 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Let admins **structure the email format** — an editable template with
  **reusable tags** (`<username>`, `<email>`, …) and a **signature** — from the
  Email settings page.
- **Status:** Applied (backend + frontend). Verified via API/container render and
  in-browser. Builds on 0066 (SMTP) / 0067 (reset email).

## What changed
### Backend
- **`core/app_settings.py`:** new template settings — `email_signature` (blank),
  `email_reset_subject`, `email_reset_body` (defaults carry the tag placeholders)
  — plus an `EMAIL_TEMPLATE_TAGS` list for the UI hint.
- **`core/email.py`:** new `render_template(text, context)` — replaces `<tag>`
  placeholders in **one pass** (a substituted value, e.g. the signature, isn't
  re-scanned) via a regex that only matches letter/underscore-led names, so URLs
  in angle brackets and `<3` are left untouched; unknown tags stay literal. Also
  `signature_for(session, tenant)`.
- **`routes/auth.py` (password reset):** the email now renders from
  `email_reset_subject` / `email_reset_body` with context `username`, `email`,
  `reset_link`, `expiry_minutes`, `signature`, `from_name`, `site_url`. **Safety
  net:** if the body omits `<reset_link>`, the link is appended so a mis-edited
  template can't send an unusable reset email; a blank subject falls back to the
  default.
- **`routes/registration.py`** and the **test email** (`routes/email_admin.py`)
  now append the signature too.
- **Email config API** (`schemas/email.py` + `routes/email_admin.py`): read/write
  `email_signature`, `email_reset_subject`, `email_reset_body` (template fields
  keep their exact whitespace/newlines; not stripped).

### Frontend
- **`screens/email_settings_screen.dart`:** a new **Email content** card — a tag
  legend, a multiline **Signature**, and the **Password-reset email** Subject +
  multiline Body — loaded/saved through the existing email-config call.

## Verification
- `python -m compileall` + `flutter analyze` — clean; `flutter build web` — ok;
  backend hot-reloaded healthy.
- **`render_template` unit checks (container):** tags substituted; `<username>`
  inside the signature not re-processed (single pass); `<unknown_tag>` left as-is;
  `<http://example.com>` and `<3` not mangled.
- **API:** config now returns the three template fields; a PUT of a custom
  signature + multiline subject/body round-trips with newlines intact.
- **End-to-end render (container, real stored template):** the reset email came
  out fully substituted with the signature appended.
- **In-browser:** the Email content card renders (tag hint, signature, reset
  subject/body); typing a multiline signature and **Save** persisted it (DB
  confirmed). Test signature cleared afterward so the owner starts blank.

## Rollback
- Revert the backend + `email_settings_screen.dart` edits; delete this changelog.
  The `email_signature` / `email_reset_*` settings rows can be left or deleted.
