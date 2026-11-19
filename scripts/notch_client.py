"""Zero-dependency Python client to push Live Activities into NotchHub (127.0.0.1:47890)."""

from __future__ import annotations

import json
import urllib.request
from typing import Literal

ActivityState = Literal["idle", "thinking", "running", "waiting_approval", "done", "error"]


def push_notch_activity(
    activity_id: str,
    source: str,
    state: ActivityState,
    title: str,
    detail: str = "",
    progress: float | None = None,
    port: int = 47890,
    timeout: float = 1.5,
) -> bool:
    """Push or update an activity on NotchHub. Fails silently (returns False) if NotchHub isn't running."""
    payload: dict[str, object] = {
        "id": activity_id,
        "source": source,
        "state": state,
        "title": title,
        "detail": detail,
    }
    if progress is not None:
        payload["progress"] = max(0.0, min(1.0, float(progress)))

    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/activity",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200
    except Exception:
        return False


def clear_notch_activity(activity_id: str, port: int = 47890, timeout: float = 1.5) -> bool:
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/activity/{activity_id}",
        method="DELETE",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200
    except Exception:
        return False
