# Pattern: Daily Triage

**Skill:** `loop-triage` · **Verifier:** `loop-verifier` (L2+) · **Cadence:** 1d → 2h

Start each active period with a prioritized, actionable picture of what needs attention,
without re-reading everything yourself.

## Loop anatomy

```
schedule (cron / claude /loop)
   └─> bin/run-loop.sh
        ├─ read LOOP.md          (autonomy level + cap)
        ├─ gather signals        (CI runs, issues, recent commits via gh)
        ├─ bin/cost-gate.sh      (stop if projected spend > cap)
        ├─ claude --print        (loop-triage skill rewrites the state)
        └─ write STATE.md + loop-run-log.md
```

## Inputs
- Prior `STATE.md` (memory of earlier runs)
- CI / workflow runs, last 24h
- Open issues / PRs
- Commits to default branch, last 24–48h

## Outputs
- Rewritten `STATE.md`: High Priority / Watch / Noise / Human-flagged / Facts for next run
- A `loop-run-log.md` entry per run

## Autonomy progression
| Level | Behavior |
|-------|----------|
| L1 | Report only. Rewrites `STATE.md`. **Start here.** |
| L2 | Proposes small fixes in a worktree → `loop-verifier` PASS → opens a PR (human merges). |
| L3 | Auto-merges only allowlisted change classes (see LOOP.md). |

## Cost profile
~5k–200k tokens/run depending on repo activity. Default cap: 100k/day (`LOOP.md`).
`cost-gate.sh` enforces it before each run.

## Failure modes & guards
- **State bloat** → skill prunes resolved items every run.
- **Re-surfacing dismissed noise** → keep a Noise/Ignore section so the next run skips it.
- **Silent loss of human overrides** → skill carries forward `Facts for next run`.
- **Runaway spend** → `cost-gate.sh` hard-stops over cap.
