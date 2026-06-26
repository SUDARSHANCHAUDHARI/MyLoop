#!/usr/bin/env bash
# run-loop.sh — the runnable core of MyLoop.
#
# This is the piece most "loop" templates leave as a TODO. It actually:
#   1. reads the autonomy level from LOOP.md
#   2. gathers live signals (CI runs, issues, recent commits) via gh
#   3. runs the cost gate BEFORE spending tokens
#   4. composes a prompt = contract + skill + state + signals
#   5. invokes Claude Code headless and writes the new STATE.md
#   6. appends a run-log entry
#
# Usage:
#   bin/run-loop.sh                 # run the loop-triage loop
#   bin/run-loop.sh --skill loop-triage
#   bin/run-loop.sh --dry-run       # print the composed prompt, spend nothing
#   MODEL=claude-sonnet-4-6 bin/run-loop.sh
#
# Requires: claude CLI. Optional: gh (for live signals).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKILL="loop-triage"
DRY_RUN=0
MODEL="${MODEL:-claude-opus-4-8}"

while [ $# -gt 0 ]; do
  case "$1" in
    --skill)   SKILL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SKILL_FILE="skills/${SKILL}/SKILL.md"
[ -f "$SKILL_FILE" ] || { echo "✗ No skill at $SKILL_FILE" >&2; exit 1; }

# --- 1. Read the contract ---------------------------------------------------
LEVEL="$(grep -E '^LEVEL:' LOOP.md | head -1 | awk '{print $2}')"
LEVEL="${LEVEL:-L1}"
CAP="$(grep -E '^DAILY_TOKEN_CAP:' LOOP.md | head -1 | awk '{print $2}')"
CAP="${CAP:-100000}"
echo "▶ Loop: $SKILL   Level: $LEVEL   Cap: $CAP tokens"

# --- 2. Seed state if missing ------------------------------------------------
if [ ! -f STATE.md ]; then
  cp STATE.md.template STATE.md
  echo "  seeded STATE.md from template"
fi

# --- 3. Gather live signals (best-effort) ------------------------------------
signals() {
  command -v gh >/dev/null 2>&1 || { echo "(gh not installed — no live signals)"; return; }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "(not a git repo — no live signals)"; return; }
  echo "### Recent CI runs"
  gh run list --limit 10 --json conclusion,name,headBranch,createdAt 2>/dev/null \
    | head -c 4000 || echo "(none / no access)"
  echo
  echo "### Open issues"
  gh issue list --limit 15 --json number,title,labels 2>/dev/null \
    | head -c 4000 || echo "(none / no access)"
  echo
  echo "### Recent commits"
  git log --since="48 hours ago" --pretty=format:'- %h %s' 2>/dev/null | head -40 || echo "(none)"
}
SIGNALS="$(signals)"

# --- 4. Compose the prompt ---------------------------------------------------
read -r -d '' GUARD <<EOF || true
You are running the "$SKILL" loop at autonomy level $LEVEL.
Honor the contract in LOOP.md. At L1 you may ONLY rewrite STATE.md — no code edits, no git.
EOF

PROMPT="$GUARD

----- LOOP CONTRACT (LOOP.md) -----
$(cat LOOP.md)

----- SKILL: $SKILL -----
$(cat "$SKILL_FILE")

----- CURRENT STATE.md -----
$(cat STATE.md)

----- LIVE SIGNALS -----
$SIGNALS

----- YOUR TASK -----
Run the $SKILL skill against the signals and current state.
Output ONLY the full new contents of STATE.md. No code fences, no commentary."

# --- 5. Cost gate (before spending) -----------------------------------------
bash bin/cost-gate.sh --chars "${#PROMPT}" --cap "$CAP" || {
  echo "✗ Cost gate stopped the run. Raise DAILY_TOKEN_CAP in LOOP.md or trim STATE.md." >&2
  exit 1
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "----- DRY RUN: composed prompt below -----"
  printf '%s\n' "$PROMPT"
  exit 0
fi

# --- 6. Invoke Claude Code headless -----------------------------------------
command -v claude >/dev/null 2>&1 || { echo "✗ claude CLI not found" >&2; exit 1; }
echo "  invoking claude ($MODEL)…"
ERR_FILE="$(mktemp)"
trap 'rm -f "$ERR_FILE"' EXIT
if ! OUT="$(printf '%s' "$PROMPT" | claude --print --model "$MODEL" 2>"$ERR_FILE")"; then
  echo "✗ claude invocation failed:" >&2
  cat "$ERR_FILE" >&2
  [ -n "$OUT" ] && printf '%s\n' "$OUT" >&2   # claude reports some errors on stdout
  echo "  (headless runs need a logged-in claude CLI or ANTHROPIC_API_KEY in the environment)" >&2
  exit 1
fi

[ -n "$OUT" ] || { echo "✗ empty response — STATE.md left unchanged" >&2; exit 1; }

# --- 7. Write state + run-log -----------------------------------------------
printf '%s\n' "$OUT" > STATE.md
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "## $TS — $SKILL @ $LEVEL"
  echo "- prompt chars: ${#PROMPT}  model: $MODEL"
  echo "- state bytes after: $(wc -c < STATE.md | tr -d ' ')"
  echo
} >> loop-run-log.md

echo "✓ STATE.md updated. Logged to loop-run-log.md."
