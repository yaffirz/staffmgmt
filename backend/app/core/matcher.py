"""Thin client for the fingerprint matcher microservice (SourceAFIS via nodeafis)."""

import json
import urllib.request

from app.core.config import settings as app_config


def verify(probe: str, candidates: list[str]) -> dict:
    """POST a probe + candidate PNG samples to the matcher. Returns
    {score, bestIndex, match, threshold}. Raises on transport/HTTP errors."""
    url = app_config.MATCHER_URL.rstrip("/") + "/verify"
    body = json.dumps({"probe": probe, "candidates": candidates}).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=60) as resp:  # noqa: S310 (internal URL)
        return json.loads(resp.read().decode())
