# MyLoop

**Loop Engineering for Claude Code — but the loop actually runs.**

> You don't prompt the agent. You design the loop that prompts the agent.
> Your job is to stay the engineer who owns the loop, not the one who presses go.

Most "loop" templates hand you docs and leave the agent call as a `# TODO: wire your harness`.
MyLoop ships the runnable part: [`bin/run-loop.sh`](bin/run-loop.sh) gathers signals, gates
the cost, invokes Claude Code headless, and rewrites a persistent state file — on a schedule.

It adds three things a naive autonomous loop skips:

1. **An autonomy ladder** (`L1 → L2 → L3`) you earn, instead of starting at full self-merge.
2. **A maker/checker split** — a separate `loop-verifier` must PASS before any fix becomes a PR.
3. **A pre-run cost gate** — estimates spend and refuses to run over your cap, *before* spending.

---

## The four moving parts

| Part | File | Role |
|------|------|------|
| **Contract** | [`LOOP.md`](LOOP.md) | Autonomy level, token cap, hard rules. The one source of truth. |
| **Memory spine** | [`STATE.md`](STATE.md) | The agent reads it, acts, rewrites it. Continuity for a stateless model. |
| **Skill** | [`skills/loop-triage/SKILL.md`](skills/loop-triage/SKILL.md) | What the loop actually does. The "maker". |
| **Runner** | [`bin/run-loop.sh`](bin/run-loop.sh) | Composes prompt + signals + state → Claude Code → new state. |

Checker for L2+: [`skills/loop-verifier/SKILL.md`](skills/loop-verifier/SKILL.md).
Cost gate: [`bin/cost-gate.sh`](bin/cost-gate.sh).

---

## Quick start (60 seconds)

```bash
# 1. See exactly what the loop would send — spends nothing
bin/run-loop.sh --dry-run

# 2. Run it for real (needs the `claude` CLI logged in)
bin/run-loop.sh

# 3. Read the result
cat STATE.md
```

Three ways to schedule it:

| How | Command |
|-----|---------|
| **Claude Code** | `/loop 1d bin/run-loop.sh` (self-paced or interval) |
| **cron** | `0 8 * * 1-5  cd /path/to/MyLoop && bin/run-loop.sh` |
| **GitHub Actions** | [`.github/workflows/daily-triage.yml`](.github/workflows/daily-triage.yml) (set `ANTHROPIC_API_KEY` secret) |

---

## The autonomy ladder

You never start at the top. You graduate.

```
L1  Report-only      reads signals, rewrites STATE.md. No code. No git.     ← always start here
L2  Assisted fix     small fix in a worktree → loop-verifier PASS → PR      ← earn after a clean week of L1
L3  Unattended       auto-merge ONLY allowlisted change classes            ← earn after a fortnight of good L2 PRs
```

Flip the level in one place — the `LEVEL:` line in [`LOOP.md`](LOOP.md). The runner and the
GitHub Action both read it. Entry checklists for each level live in that file.

---

## Repo layout

```
MyLoop/
├── LOOP.md                       # the contract (autonomy + budget + rules)
├── STATE.md                      # memory spine (committed; seeded from .template)
├── STATE.md.template
├── bin/
│   ├── run-loop.sh               # runnable core — invokes Claude Code
│   └── cost-gate.sh              # pre-run token estimate vs cap
├── skills/
│   ├── loop-triage/SKILL.md      # the maker
│   └── loop-verifier/SKILL.md    # the checker (L2+)
├── patterns/daily-triage.md      # the worked pattern
├── examples/claude-code/         # tool-specific usage
├── .github/workflows/            # the scheduler
└── LEARN.md                      # start here if you're new to loops
```

New to this? Read [`LEARN.md`](LEARN.md) and run the dry-run.

---

## Credit

The Loop Engineering framing — five primitives + memory, the L1→L3 phasing, the maker/checker
pattern — is from Cobus Greyling's [loop-engineering](https://github.com/cobusgreyling/loop-engineering),
building on Peter Steinberger and Boris Cherny. MyLoop is an independent, runnable implementation
for Claude Code. MIT licensed.
