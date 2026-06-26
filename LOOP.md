# LOOP.md — Loop Contract

> This file is the **contract** for every loop in this repo. The runner (`bin/run-loop.sh`)
> reads it and enforces it. Change the autonomy level here, not in scattered scripts.
>
> Core idea (Loop Engineering): you don't prompt the agent — you design the loop that prompts it.
> Your job is to stay the engineer who owns this contract.

## Active level

```
LEVEL: L1
```

Set this to `L1`, `L2`, or `L3`. The runner reads this exact line.

## Autonomy ladder

The whole point of this file. You **earn** your way up the ladder; you never start at the top.

| Level | Name           | What the agent may do                                   | Gate to enter |
|-------|----------------|---------------------------------------------------------|---------------|
| **L1** | Report-only    | Read signals, rewrite `STATE.md`. No code edits. No git. | Default. Always start here. |
| **L2** | Assisted fix   | L1 + small self-contained fixes in a **worktree**, each verified by the `loop-verifier` checker, opened as a **PR** (never merged). | One full week of clean L1 runs + you've read every STATE.md. |
| **L3** | Unattended     | L2 + auto-merge of **allowlisted** change classes only (e.g. patch-level dep bumps, formatting). | Two weeks of L2 PRs you'd have approved unchanged + an explicit allowlist below. |

### L2 entry checklist (do not flip to L2 until all true)
- [ ] 7+ consecutive L1 runs with no surprises in `STATE.md`
- [ ] A `loop-verifier` checker skill exists and has been tested
- [ ] Every fix runs in an isolated git worktree, discarded on rejection
- [ ] Output is a PR — a human still merges

### L3 allowlist (only change classes listed here may auto-merge)
```
# (empty — nothing auto-merges until you list it)
# example once trusted:
# - dependency patch bumps that keep the build green
```

## Hard rules (all levels)
- **Never** push to `main`/`master`. Branch + PR only (L2+).
- **Never** edit files outside the current task's scope.
- **Never** auto-fix without the `loop-verifier` checker passing (L2+).
- Prune resolved items from `STATE.md` every run — the spine must not bloat.
- Flag for human: design decisions, security work, anything unresolved 3+ runs.

## Engine
Which model/agent the loop calls. The runner reads these; env vars override them.
```
ENGINE: claude
ENGINE_MODEL: claude-opus-4-8
ENGINE_CMD:
```
- `claude` — Claude Code. Uses your login locally; needs a token/key only in CI.
- `ollama` — fully **local** model (free, offline, no key). Set `ENGINE_MODEL: llama3.1` etc.
- `opencode` — OpenCode CLI; model via its own provider config or `ENGINE_MODEL`.
- `custom` — set `ENGINE_CMD` to any command that reads a prompt on stdin, prints completion on stdout.

## Budget
```
DAILY_TOKEN_CAP: 100000
```
`bin/cost-gate.sh` estimates each run against this cap **before** spending. Over cap → it stops and asks.
Local engines (`ollama`) skip the cap — the estimate is shown but never blocks.

## Spawn budget
```
L1_MAX_SUBAGENTS: 0
L2_MAX_SUBAGENTS: 1   # the verifier
L3_MAX_SUBAGENTS: 2
```

## Connectors (MCP)
- L1: read-only connectors only (gh read, issue read).
- L2: read + comment.
- L3: read + write, scoped to the allowlist above.
