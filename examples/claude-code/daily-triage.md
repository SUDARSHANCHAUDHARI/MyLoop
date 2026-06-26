# Claude Code — daily-triage loop

## One-shot (manual)
```bash
bin/run-loop.sh
```

## Scheduled inside Claude Code
Use the `/loop` command. Interval form runs on a cadence; bare form lets the model self-pace.

```
/loop 1d bin/run-loop.sh
```

Week-one discipline (stay at L1):
```
/loop 1d Run bin/run-loop.sh. Report only — do not change LOOP.md level. Summarize STATE.md diff.
```

## Graduating to L2
1. Confirm 7+ clean L1 runs in `loop-run-log.md`.
2. Verify `skills/loop-verifier/SKILL.md` behaves (feed it a bad diff, expect REJECT).
3. Set `LEVEL: L2` in `LOOP.md`.
4. Now the loop may open PRs — but `loop-verifier` must PASS first, and a human still merges.

## Headless / CI
The same `bin/run-loop.sh` runs in GitHub Actions — see
[`../../.github/workflows/daily-triage.yml`](../../.github/workflows/daily-triage.yml).
Set the `ANTHROPIC_API_KEY` repo secret. The job's read-only token enforces L1 at the platform level.

## Notes
- `MODEL=claude-sonnet-4-6 bin/run-loop.sh` to run cheaper for high-frequency loops.
- `bin/run-loop.sh --dry-run` always shows the exact prompt without spending.
