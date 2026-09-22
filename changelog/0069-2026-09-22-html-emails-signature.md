# Changelog 0069 — HTML emails + formatted (HTML) signature

- **Timestamp:** 2026-09-22 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Support a **formatted email signature** (bold/colour/links/logos).
  The signature field only accepted plain text because emails were sent as plain
  text; send **HTML emails** so a rich signature works.
- **Status:** Applied (backend + frontend). Verified via container render + API
  and in-browser. Builds on 0066–0068.

## What changed
### Backend
- **`core/app_settings.py`:** new `email_html` toggle (default **false** — plain
  text, the historical behaviour). On = HTML.
- **`core/email.py`:**
  - `_deliver` / `send_email` now take an optional `html`; when given, the message
    is **multipart/alternative** (plain-text part + HTML part).
  - New HTML helpers: `_escape_linkify_br` (escape text, linkify http(s) URLs,
    newlines → `<br>`), `html_to_text` (fallback text), `_wrap_html`.
  - **`compose_message(session, tenant, body_template, context)`** → `(text,
    html_or_None)` honouring `email_html`. The signature is placed at
    `<signature>` via a private-use **sentinel**, so the surrounding body can be
    HTML-escaped **without escaping the (HTML) signature**. If the body already
    contains HTML it's used as-is; otherwise it's escaped + linkified. The
    plain-text part is derived from the HTML so both stay in sync.
- **`routes/auth.py`** (reset), **`routes/registration.py`** (confirm), and the
  **test email** (`routes/email_admin.py`) now build via `compose_message` and
  send both parts. Reset still force-appends `<reset_link>` if the template omits
  it.
- **Config API:** `email_html` added to read/update (`schemas/email.py` +
  `routes/email_admin.py`).

### Frontend
- **`screens/email_settings_screen.dart`:** a **"Format emails as HTML"** switch
  atop the Email content card. When on, the Signature field becomes
  **"Signature (HTML)"** — monospaced, taller, with an HTML hint ("Paste your HTML
  signature. Images need public URLs. Send a test email to preview it.").

## Verification
- `python -m compileall` + `flutter analyze` — clean; `flutter build web` — ok;
  backend hot-reloaded healthy.
- **`compose_message` (container):**
  - Plain-text mode → `html is None`; body + text signature.
  - HTML mode, plain body + **HTML signature** → HTML part has the body escaped,
    the reset URL auto-linkified to `<a>`, newlines as `<br>`, and the raw HTML
    signature (bold/colour/link/`<img>`) inserted un-escaped inside a styled
    wrapper; the text part is a clean tag-stripped fallback.
- **API:** `email_html` appears in GET config and a PUT round-trips it.
- **In-browser:** the HTML toggle flips the Signature field to "Signature (HTML)"
  with the monospace font + HTML guidance. (Test values reset to defaults; live
  config left with `email_html` off.)

## Notes / limits
- Signature **images must be public URLs**; remote images are commonly blocked by
  clients until the reader allows them (inherent to email). CID-embedded images
  would need the image files and is a possible follow-up.
- No in-app WYSIWYG editor — the signature is pasted as HTML source; the existing
  **Send test email** is the live preview.

## Rollback
- Revert the backend + `email_settings_screen.dart` edits; delete this changelog.
  The `email_html` setting row can be left or deleted.
