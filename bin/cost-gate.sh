#!/usr/bin/env bash
# cost-gate.sh — estimate a run's token cost BEFORE spending it.
#
# Most loop setups only measure spend after the fact. This gate runs first:
# it rough-estimates input tokens from the composed prompt and refuses to run
# if the projected spend exceeds the cap in LOOP.md.
#
# Estimate is intentionally simple and conservative: ~4 chars/token for input,
# plus a fixed output reserve. It is a guardrail, not an invoice.
#
# Usage:
#   bin/cost-gate.sh --chars 12000 --cap 100000
#   bin/cost-gate.sh --chars 12000              # cap read from LOOP.md
# Exit 0 = under cap (proceed). Exit 1 = over cap (stop).

set -euo pipefail

CHARS=0
CAP=""
LOCAL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --chars) CHARS="$2"; shift 2 ;;
    --cap)   CAP="$2";   shift 2 ;;
    --local) LOCAL=1;    shift ;;   # local engine: estimate only, never block
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$CAP" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  CAP="$(grep -E '^DAILY_TOKEN_CAP:' "$ROOT/LOOP.md" 2>/dev/null | head -1 | awk '{print $2}')"
  CAP="${CAP:-100000}"
fi

INPUT_TOKENS=$(( CHARS / 4 ))
OUTPUT_RESERVE=4000                    # assume the model writes a state file back
EST=$(( INPUT_TOKENS + OUTPUT_RESERVE ))
PCT=$(( EST * 100 / CAP ))

if [ "$LOCAL" -eq 1 ]; then
  echo "  cost-gate: ~${EST} tokens — local engine, no spend cap enforced."
  exit 0
fi

echo "  cost-gate: ~${EST} tokens (in ~${INPUT_TOKENS} + out ~${OUTPUT_RESERVE}) vs cap ${CAP}  (${PCT}%)"

if [ "$EST" -gt "$CAP" ]; then
  echo "  cost-gate: OVER CAP — refusing to run." >&2
  exit 1
fi
exit 0
