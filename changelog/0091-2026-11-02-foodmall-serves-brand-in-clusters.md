# 0091 — Foodmalls show under every brand they carry (Area Dashboard + Clusters)

**Date:** 2026-11-02

## What

A multi-brand **foodmall** now appears under **every brand it serves** in the
Area Dashboard and the Clusters store picker — not just its primary brand.

Example: **St Anns** is a Rituals store (primary brand) flagged as a foodmall
that also carries **Pizza Boys** (`store_brands`). It now shows under **both**
Pizza Boys and Rituals.

## Why

The 0088/0089 Area Dashboard and the 0089 Clusters screen keyed on a store's
single primary `brand_id`, so a foodmall only ever appeared under its primary
brand. That hid St Anns from the Pizza Boys views and from a Pizza Boys-focused
Area Manager's store picker. The rest of the app already uses the canonical
"serves brand" rule (primary brand ∪ `store_brands`) — this brings these two
surfaces in line.

## Changes

- **`core/scoping.py`**
  - `stores_in_brands` now also includes foodmall stores carrying one of the
    brands as an **extra** (`store_brands` join), so Ops Manager scope and the
    dashboard's per-brand store set both pick up foodmalls.
  - New `served_brand_ids(session, store)` = primary brand ∪ `store_brands`.
- **`routes/platforms.py`** — the Area Dashboard selects stores that **serve**
  the chosen brand (via `stores_in_brands({selected})`) instead of
  `brand_id == selected`. Staff are still filtered to the selected brand by
  `effective_brand_id`, so a foodmall shows only that brand's staff under each
  brand.
- **`routes/clusters.py`** — each store in the overview now carries
  `brand_names` (all served brands). Area Manager store clusters are unchanged
  (still a set of store ids).
- **Frontend** — `ClusterStoreLite.brandNames`; the Clusters store picker groups
  a store under **each** served brand (same `store_id`, so ticking it in either
  group selects the one store — no double count).

## Verified

- `python -m compileall` + `flutter analyze` / `flutter build web` clean.
- API: St Anns (store 63) `served_brand_ids` = {Pizza Boys, Rituals};
  `/area-dashboard?brand_id=1` (Pizza Boys) and `?brand_id=3` (Rituals) both list
  St Anns; Clusters overview reports `brand_names: ['Pizza Boys', 'Rituals
  Coffee House']`.
- In-browser: the AM store picker shows St Anns under both Pizza Boys and
  Rituals; ticking one ticks the other and counts as a single selection.
