# Changelog 0054 — Global top-bar controls on every page

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** The top-bar controls (notification bell, light/dark toggle, log out)
  only appeared on the dashboard; other pages were missing them.
- **Status:** Applied. `flutter analyze` clean (2 pre-existing infos elsewhere);
  built + deployed.

## Change
- New `widgets/global_bar_actions.dart` — `GlobalBarActions` (bell + theme toggle
  + log out), the same trio the dashboard showed.
- `widgets/app_scaffold.dart` — when a page supplies an `AppBar` (and doesn't opt
  out), `AppScaffold` now appends `GlobalBarActions` to that bar's `actions`, so
  every signed-in page carries the controls without editing all 27 screens. A new
  `globalActions` flag (default true) lets a page opt out.
- Opted out (`globalActions: false`): **dashboard** (already builds its own trio,
  avoids duplicates), **register** and **maintenance** (pre-login / gate pages).
  The login screen has no AppBar, so it is unaffected.

## Notes
- The notification bell already swallows fetch errors, so it's safe on
  restricted-role pages (Store/Foodmall) — it simply shows no count there.
- Page-specific actions (e.g. Employees list: refresh / add / filter) stay first;
  the global trio is appended after them.

## Rollback
- Revert the three screen edits + `app_scaffold.dart`, and delete
  `global_bar_actions.dart`.
