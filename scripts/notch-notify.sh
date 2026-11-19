#!/usr/bin/env bash
set -euo pipefail

# Push a Live Activity to NotchHub (http://127.0.0.1:47890)
# Usage:
#   ./scripts/notch-notify.sh <id> <source> <state> <title> [detail] [progress 0.0-1.0]
# States: idle | thinking | running | waiting_approval | done | error

ID="${1:-job-1}"
SOURCE="${2:-Agent}"
STATE="${3:-running}"
TITLE="${4:-Working...}"
DETAIL="${5:-}"
PROGRESS="${6:-}"
PORT="${NOTCHHUB_PORT:-47890}"

PAYLOAD=$(python3 - <<PY
import json
d = {
    "id": """$ID""",
    "source": """$SOURCE""",
    "state": """$STATE""",
    "title": """$TITLE""",
    "detail": """$DETAIL""",
}
prog = """$PROGRESS""".strip()
if prog:
    d["progress"] = float(prog)
print(json.dumps(d))
PY
)

curl -sS -X POST "http://127.0.0.1:${PORT}/v1/activity" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
echo ""
