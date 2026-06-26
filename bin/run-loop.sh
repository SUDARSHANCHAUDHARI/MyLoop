#!/usr/bin/env bash
# run-loop.sh — the runnable core of MyLoop.
#
# This is the piece most "loop" templates leave as a TODO. It actually:
#   1. reads the autonomy level + engine from LOOP.md
#   2. gathers live signals (CI runs, issues, recent commits) via gh
#   3. runs the cost gate BEFORE spending (skipped for local engines)
#   4. composes a prompt = contract + skill + state + signals
#   5. invokes the chosen engine and writes the new STATE.md
#   6. appends a run-log entry
#
# The engine is pluggable — pick one in LOOP.md (or override with env):
#   claude    Claude Code (default). Uses your login locally; key/token in CI.
#   ollama    Fully LOCAL model. No key, no network, free. e.g. ENGINE_MODEL=llama3.1
#   opencode  OpenCode CLI (its own provider config — can be local or cloud).
#   custom    Any command that reads a prompt on stdin and prints completion on stdout.
#
# Usage:
#   bin/run-loop.sh                       # run the loop-triage loop
#   bin/run-loop.sh --skill loop-triage
#   bin/run-loop.sh --dry-run             # print the composed prompt, spend/run nothing
#   ENGINE=ollama ENGINE_MODEL=llama3.1 bin/run-loop.sh
#   ENGINE=custom ENGINE_CMD='my-llm --stdin' bin/run-loop.sh
#
# Requires: the chosen engine's CLI. Optional: gh (for live signals).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKILL="loop-triage"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --skill)   SKILL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SKILL_FILE="skills/${SKILL}/SKILL.md"
[ -f "$SKILL_FILE" ] || { echo "✗ No skill at $SKILL_FILE" >&2; exit 1; }

# --- helper: read a "KEY: value" line from LOOP.md --------------------------
loop_cfg() { grep -E "^$1:" LOOP.md | head -1 | sed -E "s/^$1:[[:space:]]*//" | sed -E 's/[[:space:]]+#.*$//'; }

# --- 1. Read the contract ---------------------------------------------------
LEVEL="$(loop_cfg LEVEL)";        LEVEL="${LEVEL:-L1}"
CAP="$(loop_cfg DAILY_TOKEN_CAP)"; CAP="${CAP:-100000}"

# Engine: env override > LOOP.md > default
ENGINE="${ENGINE:-$(loop_cfg ENGINE)}";           ENGINE="${ENGINE:-claude}"
ENGINE_MODEL="${MODEL:-${ENGINE_MODEL:-$(loop_cfg ENGINE_MODEL)}}"
ENGINE_CMD="${ENGINE_CMD:-$(loop_cfg ENGINE_CMD)}"

# Per-engine model default (only if none configured)
if [ -z "$ENGINE_MODEL" ]; then
  case "$ENGINE" in
    claude)  ENGINE_MODEL="claude-opus-4-8" ;;
    ollama)  ENGINE_MODEL="llama3.1" ;;
    *)       ENGINE_MODEL="" ;;   # opencode/custom: let the tool decide
  esac
fi

# Which engines are local/free (cost gate is informational, never blocks)
case "$ENGINE" in ollama) LOCAL=1 ;; *) LOCAL=0 ;; esac

echo "▶ Loop: $SKILL   Level: $LEVEL   Engine: $ENGINE ${ENGINE_MODEL:+($ENGINE_MODEL)}"

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
if [ "$LOCAL" -eq 1 ]; then
  bash bin/cost-gate.sh --chars "${#PROMPT}" --cap "$CAP" --local || true
else
  bash bin/cost-gate.sh --chars "${#PROMPT}" --cap "$CAP" || {
    echo "✗ Cost gate stopped the run. Raise DAILY_TOKEN_CAP in LOOP.md or trim STATE.md." >&2
    exit 1
  }
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "----- DRY RUN: composed prompt below -----"
  printf '%s\n' "$PROMPT"
  exit 0
fi

# --- 6. Invoke the engine ----------------------------------------------------
# Each branch reads PROMPT on stdin and must print the new STATE.md on stdout.
invoke_engine() {
  case "$ENGINE" in
    claude)
      command -v claude >/dev/null 2>&1 || { echo "✗ claude CLI not found" >&2; return 127; }
      claude --print --model "$ENGINE_MODEL"
      ;;
    ollama)
      command -v ollama >/dev/null 2>&1 || { echo "✗ ollama not found — install from ollama.com" >&2; return 127; }
      ollama run "$ENGINE_MODEL"
      ;;
    opencode)
      command -v opencode >/dev/null 2>&1 || { echo "✗ opencode CLI not found" >&2; return 127; }
      if [ -n "$ENGINE_MODEL" ]; then opencode run --model "$ENGINE_MODEL"; else opencode run; fi
      ;;
    custom)
      [ -n "$ENGINE_CMD" ] || { echo "✗ ENGINE=custom needs ENGINE_CMD set" >&2; return 2; }
      eval "$ENGINE_CMD"
      ;;
    *)
      echo "✗ Unknown ENGINE: $ENGINE (use claude|ollama|opencode|custom)" >&2; return 2 ;;
  esac
}

echo "  invoking $ENGINE…"
ERR_FILE="$(mktemp)"
trap 'rm -f "$ERR_FILE"' EXIT
if ! OUT="$(printf '%s' "$PROMPT" | invoke_engine 2>"$ERR_FILE")"; then
  echo "✗ engine '$ENGINE' failed:" >&2
  cat "$ERR_FILE" >&2
  [ -n "${OUT:-}" ] && printf '%s\n' "$OUT" >&2   # some CLIs report errors on stdout
  [ "$ENGINE" = "claude" ] && echo "  (headless claude needs a login, CLAUDE_CODE_OAUTH_TOKEN, or ANTHROPIC_API_KEY)" >&2
  exit 1
fi

[ -n "$OUT" ] || { echo "✗ empty response — STATE.md left unchanged" >&2; exit 1; }

# --- 7. Write state + run-log -----------------------------------------------
printf '%s\n' "$OUT" > STATE.md
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  echo "## $TS — $SKILL @ $LEVEL"
  echo "- engine: $ENGINE ${ENGINE_MODEL:+model=$ENGINE_MODEL}  local=$LOCAL"
  echo "- prompt chars: ${#PROMPT}  state bytes after: $(wc -c < STATE.md | tr -d ' ')"
  echo
} >> loop-run-log.md

echo "✓ STATE.md updated. Logged to loop-run-log.md."
