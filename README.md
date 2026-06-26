# MyLoop

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Made for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-7c6cfc)

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

---

## Running modes & auth — pick what fits you

The loop is a shell script that calls an agent CLI. **Where** you run it decides whether you
need a credential at all. You don't have to choose one mode forever — all three ship here.

| Mode | How | Auth needed |
|------|-----|-------------|
| **Local, interactive** | `bin/run-loop.sh` in your terminal, or `/loop 1d bin/run-loop.sh` inside Claude Code | **None.** Uses your existing `claude login` session. |
| **Local, cron** | `0 8 * * 1-5  cd /path/to/MyLoop && bin/run-loop.sh` | **None**, as long as your machine has `claude` logged in. |
| **Unattended (GitHub Actions)** | [`.github/workflows/daily-triage.yml`](.github/workflows/daily-triage.yml) | **One credential** (below) — there's no logged-in session on a CI box. |

### Why CI needs a credential
A scheduled Action runs on a fresh VM with nobody logged in — nothing to borrow auth from.
So one of these repo secrets must be set (you need **only one**):

| Secret | What it is | Cost |
|--------|-----------|------|
| `CLAUDE_CODE_OAUTH_TOKEN` | run `claude setup-token`, paste the result | **Uses your Claude subscription — no extra billing.** Recommended. |
| `ANTHROPIC_API_KEY` | a pay-per-token API key | Metered API billing, separate from your plan. |

The workflow auto-detects whichever you set. Set neither and it fails fast with a clear message.

### Don't want CI at all?
Delete `.github/workflows/daily-triage.yml` and run MyLoop purely locally — you'll never touch a key.

### Engines — Claude, a local model, or anything

The loop isn't tied to Claude. Pick the engine in [`LOOP.md`](LOOP.md) (or override via env):

| `ENGINE` | What runs | Key/token needed? |
|----------|-----------|-------------------|
| `claude` | Claude Code (default) | local: no (your login). CI: yes (token or key). |
| `ollama` | **A fully local model** — runs on your machine, offline | **Never. No key anywhere, even in CI.** Free. |
| `opencode` | OpenCode CLI (its own provider config) | depends on the provider you point it at |
| `custom`  | any command via `ENGINE_CMD` (reads prompt on stdin → completion on stdout) | whatever that tool needs |

The headline: **with `ENGINE: ollama` you need no API key at all** — the model is local, so even an
unattended/scheduled run costs nothing and works offline. The cost gate becomes informational only.

```bash
# fully local, free, no key — install ollama first, then:
ENGINE=ollama ENGINE_MODEL=llama3.1 bin/run-loop.sh

# any other CLI you like:
ENGINE=custom ENGINE_CMD='my-llm --stdin' bin/run-loop.sh
```

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
for Claude Code.

---

## Author

**Sudarshan Chaudhari** — SudarshanTechLabs
GitHub: [@SUDARSHANCHAUDHARI](https://github.com/SUDARSHANCHAUDHARI)

## License

Released under the [MIT License](LICENSE). © 2026 Sudarshan Chaudhari (SudarshanTechLabs).
