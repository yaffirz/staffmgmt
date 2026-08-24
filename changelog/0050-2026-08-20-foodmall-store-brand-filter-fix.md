# Changelog 0050 — Foodmall stores now appear under every brand they carry

- **Timestamp:** 2026-08-20 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A store marked as a **foodmall** (carrying multiple brands) did not
  show up in the store dropdown when one of its **extra** carried brands was
  selected — only under its primary brand.
- **Status:** Fixed and verified in the browser (selecting "Rituals Cafe" now
  lists the Arouca foodmall in the Primary-store dropdown). `flutter analyze`
  clean; built + deployed.

## Root cause
A foodmall store carries its primary `brand_id` **plus** extra brands in
`store_brands` (returned to the client as `extra_brand_ids`). The store pickers
filtered only on the primary brand:

```dart
_stores.where((s) => s.brandId == _brandId)
```

so the store never appeared under any of its additional carried brands.

## Fix
- `models/directory.dart` — `Store.servesBrand(brandId)` = primary brand **or**
  an extra carried brand (mirrors `Position.availableForBrand`).
- `screens/new_hire_wizard_screen.dart` — `_storesForBrand` uses `servesBrand`.
- `screens/employee_quick_edit_dialog.dart` — same fix in its `_storesForBrand`.

This covers the new-hire wizard's Primary-store and Additional-stores pickers
and the quick-edit profile popup. (Assigning such a store was already fine
server-side — create/update only checks the store is in the tenant.)

## Note
This does not change which brands a foodmall carries. A store still only appears
under the brands actually chosen for it (its primary brand + its foodmall extra
brands, editable in Brands & Stores → Stores). "Rituals Cafe" and "Rituals
Coffee House" are separate brands — a foodmall carrying one does not carry the
other.

## Rollback
- Revert the three edits.
