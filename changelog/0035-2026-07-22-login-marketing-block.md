# Changelog 0035 — Customizable login marketing block

- **Timestamp:** 2026-07-22 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Use the empty area on the login screen as a marketing space —
  admin-editable, shown on desktop & mobile, supporting text, image, and
  video/other-media, changeable whenever needed.
- **Status:** Applied; backend verified (public endpoint + admin save); frontend
  builds and `flutter analyze` clean (only expected `dart:html` web-lints on the
  embed file). Live through the tunnel.

## Design
- Media is supplied by **URL/embed link** (host images/videos elsewhere; paste a
  direct image URL or a YouTube/Vimeo embed URL). No file-upload/storage.
- **Web-complete, mobile-graceful:** on web the embed renders in an `<iframe>`
  (video/other media plays inline); on the Android app, text + image render
  natively and an embed shows a tappable link card — no webview dependency. The
  web-only iframe code is behind a conditional import so the APK still builds
  (same pattern as `services/bulk_io.dart`, changelog 0028).

## Backend
- `app_settings.py`: new settings `marketing_enabled` (bool), `marketing_type`
  (`text`|`image`|`embed`), `marketing_title`, `marketing_content`.
- `schemas/marketing.py`, `routes/marketing.py`: public `GET /api/v1/marketing`
  (unauthenticated, like the maintenance endpoint) returning the block; type is
  clamped to the allowed set. Registered in `main.py`.
- Admin edits reuse the existing `PATCH /api/v1/settings/{key}` (Admin/Super
  Admin), which audit-logs each change.

## Frontend
- `models/marketing_content.dart`, `state/marketing_provider.dart` (public fetch;
  the login screen re-fetches on appear so native works after server setup),
  `staff_service.dart` `marketingContent()`.
- `widgets/marketing_block.dart` renders text/image/embed, colour-tuned for the
  teal brand panel (wide) vs page background (mobile). `widgets/marketing_embed*`
  = conditional-import trio (web iframe / native link card).
- `login_screen.dart`: block placed in the brand panel (wide) and below the form
  (mobile). `main.dart`: `MarketingProvider` registered.
- `settings_screen.dart`: new "Login marketing block" card — enable toggle (the
  standing-rule admin control), content-type dropdown, heading + content fields
  (labels/hints adapt to type), Save.

## Verification
- `GET /api/v1/marketing` returns the block; admin PATCH of the 4 keys succeeds
  and is reflected. Confirmed both locally (:8000) and through the public tunnel
  (`https://gbgstaff.atmix.io/api/v1/marketing`). Visual in-browser check was
  blocked by the preview pane not compositing this session.

## Notes
- Test placeholder content is currently **enabled** ("Now hiring…") so it's
  visible on the live login screen — change or disable it in
  **Settings → Login marketing block**.

## Deployment
- Built: web bundle rebuilt (served by the backend / tunnel). Prod: live via tunnel.

## Rollback
- Revert edits; remove `routes/marketing.py`, `schemas/marketing.py`, the four
  `marketing_*` settings, and the frontend marketing files.
