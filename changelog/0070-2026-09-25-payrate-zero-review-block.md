# Changelog 0070 — A 0.00 pay rate flags the row amber + blocks review

- **Timestamp:** 2026-09-25 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** Like the "no email" flag, a **pay rate of 0.00** must flag the
  employee row (amber) and **cannot be marked reviewed until it's fixed**.
- **Status:** Applied (backend + frontend). Verified via API and in-browser.

## What changed
### Backend
- **`core/app_settings.py`:** new `payrate_required_for_review` toggle
  (default **true**).
- **`routes/employees.py` — `set_reviewed`:** when marking a row reviewed, if
  `payrate == 0` and the toggle is on, return **400** ("Set a pay rate above 0.00
  before marking this staffer reviewed.") — so the rule can't be bypassed via the
  API. Un-reviewing (reviewed=false) is always allowed. No schema change (the
  condition is derived from the existing `employees.payrate`; `None` is not
  flagged — only an explicit 0.00).

### Frontend
- **`screens/employees_list_screen.dart`:**
  - Row tint precedence updated: **amber** now covers *no email OR 0.00 pay rate*
    (was email only), then blue (promotion), then green (reviewed). Amber wins
    over green, so a grandfathered reviewed row with 0.00 shows amber.
  - The **Pay rate** cell shows amber with an error icon when it's 0.00.
  - Clicking the review toggle on a 0.00 row is **blocked before the API call**
    with a **"Pay rate not set"** dialog (mirrors the "Email not valid" dialog);
    the row stays unreviewed. The review icon's tooltip reads "Set a pay rate
    above 0.00 before reviewing".
  - The rule respects the admin toggle (fetched on load; default on if
    unreadable); backend `ApiException` messages now surface on the review toggle.
- **`screens/settings_screen.dart`:** a **"Require a pay rate to review"** switch
  (standing rule #2).

## Verification
- `python -m compileall` + `flutter analyze` — clean (only the two pre-existing
  `use_build_context_synchronously` infos); `flutter build web` — ok; backend
  hot-reloaded healthy.
- **API:** marking a payrate-0 employee reviewed → **400**; with the toggle set
  **false** → **200** (block disabled); toggle restored → **400** again. A test
  employee's state was left unchanged (the block fires before any write).
- **In-browser:** Sandy Castillo (Chef, 0.00 XCD) shows an **amber** row (vs green
  for reviewed peers). Un-reviewing worked; trying to re-review popped the
  **"Pay rate not set"** dialog and the row stayed unreviewed. (Her original
  reviewed state/timestamp was restored afterward.)

## Notes
- Existing rows already reviewed with 0.00 (grandfathered) now show amber and
  can't be *re*-reviewed until fixed; they stay reviewed until someone un-reviews
  them. A migration to bulk-flag/un-review them was not done (out of scope).
- Only an explicit **0.00** is flagged; a blank/None pay rate is not (matches the
  request and the form's optional-payrate config).

## Rollback
- Revert the backend + two frontend edits; delete this changelog. The
  `payrate_required_for_review` setting row can be left or deleted.
