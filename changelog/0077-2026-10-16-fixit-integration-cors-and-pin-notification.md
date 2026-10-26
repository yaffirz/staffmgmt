# Changelog 0077 — Fixit integration: CORS + FIXIT_PINNED notification

- **Timestamp:** 2026-10-16 (AST, UTC-4)
- **Requested by:** Fixit build (API.md §7)
- **Task:** The new **Fixit** service (troubleshooting video library) takes identity
  from this Portal and needs two Portal-side touches, both recorded here per §7.
- **Status:** Applied (backend). Additive only — no existing behaviour changed.

## 1. CORS allow-list
Fixit's browser calls `/api/v1/auth/login`, `/auth/me` and `/store/summary` on this
Portal. The Portal's CORS is currently `allow_origins=["*"]` (see
`backend/app/main.py`), which **already permits** Fixit's origin, so no code change
was required for it to work today.

**Action for production:** when the allow-list is tightened from `*` to explicit
domains, add `FIXIT_BASE_URL` (e.g. `https://fixit.<tunnel-domain>`) to it. Left as
a documented follow-up so this change carries no risk to the live Flutter client.

## 2. New notification type `FIXIT_PINNED` + an external intake endpoint
So a fix pinned in Fixit rides this Portal's existing bell (rather than a second
inbox), Fixit's server posts a notification here.

- **`backend/app/api/routes/notifications.py`:** added
  **`POST /api/v1/notifications/external`**. It:
  - authenticates with a normal Staff Portal token (Fixit uses a **service account**),
  - accepts only an **allow-listed** type set — currently `{"FIXIT_PINNED"}` — and
    rejects anything else with 422,
  - writes a role-targeted `Notifications` row (default `recipient_role="Admin"`)
    with the given `payload`, so it shows under the existing bell and unread-count.
  - It never targets an arbitrary user and adds no new table or model.

No other files touched. The read side (inbox list, unread count, mark-read) already
handles arbitrary `type`/`payload`, so `FIXIT_PINNED` surfaces with no further change.

## Verification
- Additive route; existing notification flows and tests are unaffected.
- End-to-end against Fixit's dev Staff-Portal mock (same contract): a Fixit pin →
  `POST /notifications/external` → the notification appears for Admins.
