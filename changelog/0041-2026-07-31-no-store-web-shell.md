# Changelog 0041 — Stop Cloudflare caching stale web builds

- **Timestamp:** 2026-07-31 (AST, UTC-4)
- **Requested by:** Arif (surfaced when a new build wasn't visible)
- **Task:** New web deploys weren't showing up — Cloudflare's edge cache was
  serving a stale `main.dart.js` (fixed filename, `cf-cache-status: HIT`,
  `Age` up to the 4h default) even in incognito.
- **Status:** Applied; origin verified sending `no-store`. A one-time Cloudflare
  cache purge clears the already-cached copy.

## Change
- `backend/app/main.py`: the web static mount is now a small `_AppStatic`
  subclass of `StaticFiles` that sets **`Cache-Control: no-store`** on the mutable
  app-shell files (`.html`, `.js`, `.json` — index.html, main.dart.js,
  flutter_bootstrap.js, flutter_service_worker.js, the manifests). Binary assets
  (wasm/fonts/images) keep default caching. Cloudflare honours `no-store` and
  won't cache those files, so future `flutter build web` deploys go live
  immediately.

## Operator note
- The **currently cached** copy persists until it expires — purge once now:
  Cloudflare dashboard → atmix.io → Caching → Configuration → **Purge Everything**
  (or custom-purge `https://gbgstaff.atmix.io/main.dart.js`). Not needed again.

## Verification
- `curl -D- http://localhost:8000/main.dart.js` → `cache-control: no-store`;
  same for `/` (index.html). After a Cloudflare purge, the tunnel serves the
  fresh build and `cf-cache-status` becomes BYPASS/DYNAMIC for those files.

## Deployment
- Backend code change (reload). No image rebuild.

## Rollback
- Revert to a plain `StaticFiles` mount.
