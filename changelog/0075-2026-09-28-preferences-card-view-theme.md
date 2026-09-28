# Changelog 0075 — Universal Preferences page + card view for the employee list

- **Timestamp:** 2026-09-28 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Turn the card mockup into a real, selectable **layout**; add a
  **Preferences** page any user can open to set their appearance/layout; give it
  general per-user settings for their own instance.
- **Status:** Applied (frontend only). Verified in-browser.

## What changed
### New per-user Preferences (any signed-in user)
- **`widgets/global_bar_actions.dart`:** a **Preferences** (tune) icon added to the
  always-on top bar → opens `PreferencesScreen`.
- **`screens/preferences_screen.dart` (new):** a universal page with
  - **Appearance**: Light / Dark / **System** (segmented control).
  - **Employee list layout**: **Table / Cards**.
  Choices are saved per device (shared_preferences), so anyone can set their own.

### Appearance now supports "System"
- **`state/theme_provider.dart`:** `ThemeMode` extended to light / dark / **system**
  (`setMode`); `setDark` kept for the quick top-bar toggle. **`theme_toggle.dart`**
  now reads the *rendered* brightness so it's correct in system mode. MaterialApp
  already honours `themeMode`.

### Card view for the employee list
- **`state/view_prefs_provider.dart` (new):** `EmployeeListView { table, cards }`,
  persisted; registered in `main.dart`.
- **`screens/employees_list_screen.dart`:** when the preference is **Cards**,
  `_buildBody` renders a scrolling list of **`_EmployeeCard`**s instead of the
  table (search + filter bar kept above; the card list rebuilds via
  `AnimatedBuilder` on the data source). Each card shows the status circle
  (reviewed toggle), name, a **status chip**, the role line (position · brand ·
  store), and key facts (payroll, pay rate, phone, email, MAG, country) — with the
  same **state tints** (amber / purple / blue / green), the amber 0.00 pay rate,
  and **purple highlights on flagged cells**. Actions (flag, edit profile, notes,
  full edit, delete) go through the existing handlers, so the pay-rate review
  block and everything else behave identically.

## Verification
- `flutter analyze` — clean apart from the 2 pre-existing
  `use_build_context_synchronously` infos and one `withOpacity` (matches the
  codebase's existing style); `flutter build web` — ok.
- **In-browser:** the Preferences icon opens the page; Appearance shows
  Light/Dark/System; switching **Layout → Cards** re-rendered the list as cards
  (Sandy's card amber with "needs pay rate" + 0.00 in amber; reviewed cards green
  with a "reviewed" chip). Clicking a 0.00 card's review circle popped the
  **"Pay rate not set"** block — card actions reuse the table handlers. Reset to
  Table afterward.

## Notes
- Preferences are **per device** (localStorage-style), consistent with the
  existing dark/light setting and instant/pre-login. Syncing per account (via the
  `user_preferences` store from 0074) is an easy follow-up if wanted.
- The card view shows a fixed useful set of facts; the table's per-user column
  hiding (0074) still applies to the table view.

## Rollback
- Revert the edits and delete the two new screens/providers + this changelog.
