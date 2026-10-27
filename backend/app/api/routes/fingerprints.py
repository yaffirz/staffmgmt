"""Fingerprint enrolment for the clock-in system.

Register / modify / remove an employee's enrolled fingerprints. Scoped to the
non-Oracle roster. `template` is an opaque enrolled template produced by the
capture layer; in dev (no reader) a random token stands in, and the real
DigitalPersona WebSDK can supply a real template later without schema changes.
"""

import json
import secrets
import urllib.request
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.api.deps import require_roles
from app.api.routes.non_oracle import employee_is_non_oracle
from app.core.config import settings as app_config
from app.core.database import get_session
from app.models.models import AuditLogs, Employees, Fingerprints
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/api/v1/fingerprints", tags=["fingerprints"])

MANAGE_ROLES = ("Super Admin", "Admin", "IT")

# Fingers the UI offers; kept server-side so enrolments stay consistent.
FINGER_LABELS = (
    "left-thumb",
    "left-index",
    "left-middle",
    "left-ring",
    "left-little",
    "right-thumb",
    "right-index",
    "right-middle",
    "right-ring",
    "right-little",
)


def _naive_utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class FingerprintRead(BaseModel):
    fingerprint_id: int
    employee_id: int
    finger_label: str
    enrolled: bool  # a template is on file
    created_at: datetime
    updated_at: Optional[datetime] = None


class FingerprintCreate(BaseModel):
    employee_id: int
    finger_label: str
    # Optional: the capture layer supplies a real template. Omitted in dev → a
    # stand-in token is generated so the enrolment is still unique.
    template: Optional[str] = None


class FingerprintUpdate(BaseModel):
    finger_label: Optional[str] = None
    template: Optional[str] = None  # re-scan


def _read(f: Fingerprints) -> FingerprintRead:
    return FingerprintRead(
        fingerprint_id=f.fingerprint_id,
        employee_id=f.employee_id,
        finger_label=f.finger_label,
        enrolled=bool(f.template),
        created_at=f.created_at,
        updated_at=f.updated_at,
    )


def _require_non_oracle_employee(session: Session, employee_id: int, tenant: int) -> Employees:
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Employee not found.")
    if not employee_is_non_oracle(session, emp):
        raise HTTPException(
            status_code=400,
            detail="Fingerprints are only for Non-Oracle employees for now.",
        )
    return emp


@router.get("/employee/{employee_id}", response_model=list[FingerprintRead])
def list_for_employee(
    employee_id: int,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    emp = session.get(Employees, employee_id)
    if emp is None or emp.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Employee not found.")
    rows = session.exec(
        select(Fingerprints)
        .where(Fingerprints.employee_id == employee_id)
        .order_by(Fingerprints.finger_label)
    ).all()
    return [_read(f) for f in rows]


@router.post("", response_model=FingerprintRead, status_code=201)
def enroll(
    payload: FingerprintCreate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """Register a fingerprint for a non-Oracle employee."""
    if payload.finger_label not in FINGER_LABELS:
        raise HTTPException(status_code=422, detail="Unknown finger.")
    _require_non_oracle_employee(session, payload.employee_id, current.tenant_id)
    existing = session.exec(
        select(Fingerprints).where(
            Fingerprints.employee_id == payload.employee_id,
            Fingerprints.finger_label == payload.finger_label,
        )
    ).first()
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="That finger is already enrolled. Modify or remove it instead.",
        )
    template = (payload.template or "").strip() or f"dev-{secrets.token_urlsafe(24)}"
    row = Fingerprints(
        tenant_id=current.tenant_id,
        employee_id=payload.employee_id,
        finger_label=payload.finger_label,
        template=template,
        created_by=current.user_id,
    )
    session.add(row)
    session.commit()
    session.refresh(row)
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="INSERT",
            affected_table="fingerprints",
            record_id=str(row.fingerprint_id),
            old_value=None,
            new_value={"employee_id": row.employee_id, "finger": row.finger_label},
        )
    )
    session.commit()
    return _read(row)


@router.patch("/{fingerprint_id}", response_model=FingerprintRead)
def modify(
    fingerprint_id: int,
    payload: FingerprintUpdate,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """Re-scan (new template) and/or re-label an enrolled finger."""
    row = session.get(Fingerprints, fingerprint_id)
    if row is None or row.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Fingerprint not found.")
    if payload.finger_label is not None:
        if payload.finger_label not in FINGER_LABELS:
            raise HTTPException(status_code=422, detail="Unknown finger.")
        if payload.finger_label != row.finger_label:
            clash = session.exec(
                select(Fingerprints).where(
                    Fingerprints.employee_id == row.employee_id,
                    Fingerprints.finger_label == payload.finger_label,
                )
            ).first()
            if clash is not None:
                raise HTTPException(
                    status_code=409, detail="That finger is already enrolled."
                )
            row.finger_label = payload.finger_label
    if payload.template is not None:
        row.template = payload.template.strip() or f"dev-{secrets.token_urlsafe(24)}"
    row.updated_at = _naive_utcnow()
    session.add(row)
    session.commit()
    session.refresh(row)
    return _read(row)


@router.delete("/{fingerprint_id}", status_code=204)
def remove(
    fingerprint_id: int,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    row = session.get(Fingerprints, fingerprint_id)
    if row is None or row.tenant_id != current.tenant_id:
        raise HTTPException(status_code=404, detail="Fingerprint not found.")
    session.delete(row)
    session.add(
        AuditLogs(
            user_id=current.user_id,
            action="DELETE",
            affected_table="fingerprints",
            record_id=str(fingerprint_id),
            old_value={"employee_id": row.employee_id, "finger": row.finger_label},
            new_value=None,
        )
    )
    session.commit()


# ---- Verification (test a scan against the enrolment) ----


class VerifyRequest(BaseModel):
    employee_id: int
    sample: str  # a freshly captured PNG (base64) — the probe


class VerifyResult(BaseModel):
    match: bool
    score: float
    threshold: float
    finger_label: Optional[str] = None  # the enrolled finger that matched
    enrolled_samples: int


def _candidate_samples(rows: list[Fingerprints]) -> tuple[list[str], list[str]]:
    """Flatten the stored PNG samples across an employee's fingerprints.
    Returns (samples, labels) where labels[i] is the finger that sample i came
    from. Dev placeholders (non-JSON templates) are skipped."""
    samples: list[str] = []
    labels: list[str] = []
    for f in rows:
        try:
            parsed = json.loads(f.template)
        except (ValueError, TypeError):
            continue  # dev placeholder — not a real capture
        if not isinstance(parsed, dict):
            continue
        for s in parsed.get("samples", []) or []:
            if isinstance(s, str) and s:
                samples.append(s)
                labels.append(f.finger_label)
    return samples, labels


def _matcher_verify(probe: str, candidates: list[str]) -> dict:
    """Call the matcher microservice. Raises on transport/HTTP errors."""
    url = app_config.MATCHER_URL.rstrip("/") + "/verify"
    body = json.dumps({"probe": probe, "candidates": candidates}).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=30) as resp:  # noqa: S310 (internal URL)
        return json.loads(resp.read().decode())


@router.post("/verify", response_model=VerifyResult)
def verify(
    payload: VerifyRequest,
    current: CurrentUser = Depends(require_roles(*MANAGE_ROLES)),
    session: Session = Depends(get_session),
):
    """Test a fresh scan against an employee's enrolled fingerprints (1:N over
    their fingers). Returns whether it matches, the best score, and which finger."""
    _require_non_oracle_employee(session, payload.employee_id, current.tenant_id)
    if not (payload.sample or "").strip():
        raise HTTPException(status_code=422, detail="A scan is required.")
    rows = session.exec(
        select(Fingerprints).where(Fingerprints.employee_id == payload.employee_id)
    ).all()
    candidates, labels = _candidate_samples(rows)
    if not candidates:
        raise HTTPException(
            status_code=400,
            detail="No captured fingerprint on file to test against "
            "(re-register with the reader).",
        )
    try:
        res = _matcher_verify(payload.sample, candidates)
    except Exception as exc:  # noqa: BLE001 — surface a clean message
        raise HTTPException(
            status_code=502, detail=f"Matcher unavailable: {exc}"
        ) from exc
    best_index = res.get("bestIndex", -1)
    matched = bool(res.get("match"))
    label = (
        labels[best_index]
        if isinstance(best_index, int) and 0 <= best_index < len(labels)
        else None
    )
    return VerifyResult(
        match=matched,
        score=float(res.get("score", -1)),
        threshold=float(res.get("threshold", 40)),
        finger_label=label if matched else None,
        enrolled_samples=len(candidates),
    )
