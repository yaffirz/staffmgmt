# Changelog 0078 — Non-Oracle Employees (admin area + roster)

- **Timestamp:** 2026-10-26 (AST, UTC-4)
- **Requested by:** Arif
- **Task:** A new **Non-Oracle Employees** area in the Admin panel. IT/Admins mark
  which **brands are not on Oracle**; every employee of a non-Oracle brand is
  **auto-included** in the list, with a **per-employee override** to move an
  individual in or out regardless of their brand. The list displays like the
  employee list view. This is the roster the planned **fingerprint clock-in**
  system will be tied to (phase 2 — not built yet).
- **Status:** Applied (backend + frontend). Verified via API and in-browser.
- **Decisions (from the user):** membership = *auto by brand + manual override*;
  brand marking + the list live behind a **new card in the Admin hub**, usable by
  **IT and Admins** (and Super Admin).

## Data model (non-destructive)
- `brands.non_oracle BOOLEAN NOT NULL DEFAULT false` — IT/Admin-marked.
- `employees.non_oracle_override BOOLEAN` (nullable, tri-state):
  **NULL** = follow the brand, **TRUE** = forced into the list, **FALSE** = forced
  out. Effective membership = `override ?? (effective_brand.non_oracle)`.
  Both added via `ALTER TABLE … ADD COLUMN IF NOT EXISTS` in `core/database.py`.

## Backend
- **`models.py`:** `Brands.non_oracle`, `Employees.non_oracle_override`.
- **`schemas/employee.py`:** `EmployeeRead.non_oracle_override` (populated by
  `_enrich`, used by the Non-Oracle endpoints).
- **`routes/non_oracle.py` (new)** — prefix `/api/v1/non-oracle`, roles
  **Super Admin / Admin / IT**:
  - `GET /brands` — brands with their `non_oracle` flag.
  - `PATCH /brands/{id}` `{non_oracle}` — mark/unmark a brand (audited).
  - `GET /employees` — employees currently in the list (brand-driven ± overrides),
    same `EmployeeRead` shape as the main list, newest first.
  - `PATCH /employees/{id}` `{override: true|false|null}` — move in / out / reset
    to brand default (audited). Reuses `_enrich` + `_effective_brand_id` from the
    employees route. Registered in `main.py`.

## Frontend
- **`models/non_oracle_brand.dart` (new)** + `Employee.nonOracleOverride`.
- **`services/staff_service.dart`:** `nonOracleBrands`, `setBrandNonOracle`,
  `nonOracleEmployees`, `setEmployeeNonOracle`.
- **`screens/non_oracle_screen.dart` (new):** a two-tab screen —
  - **Employees**: search + an **Add employees** picker (move an individual in),
    and a `PaginatedDataTable` (Name, Payroll ID, Brand, Store, Position, Phone,
    Email, *In list via* = Brand/Moved in, actions) — "display similar to the
    employee list view". Row action: **Remove from list** (force out) and, when an
    override is set, **Reset to brand default**.
  - **Brands**: each brand with a **Non-Oracle** switch (cloud-off when on).
- **`admin_hub_screen.dart`:** new **Non-Oracle Employees** card (cloud-off icon),
  shown to IT / Admin / Super Admin.

## Verification
- **API:** marking Churchs Texas Chicken non-Oracle surfaced its 322 employees;
  forcing one out (`override=false`) dropped the count; adding an on-Oracle-brand
  employee (`override=true`) added them; clearing/unmarking returned the list to 0.
- **In-browser:** opened the card → Brands tab → toggled Churchs on (amber
  "Non-Oracle"); Employees tab jumped to 322 and rendered as a table; the **Add
  employees** picker moved Sandy Castillo (Rituals Sushi, on-Oracle) into the list.
  Cleaned the test state back to baseline afterwards. `flutter analyze` clean;
  `flutter build web` ok; backend `compileall` + import check ok; migration columns
  confirmed in Postgres.

## Next (phase 2, not in this change)
- Fingerprint clock-in tied to this roster (DigitalPersona 4500 reader): enrol
  prints per non-Oracle employee, record clock in/out events, surface timesheets.

## Rollback
- Drop the router + screen + model/service additions and the two columns; delete
  this changelog. (Columns are additive; leaving them is harmless.)
