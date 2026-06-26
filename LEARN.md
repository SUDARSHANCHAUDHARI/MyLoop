# LEARN.md — understand loops by running one

The fastest way to "get" loop engineering is to watch one run. This takes ~10 minutes.

## Step 1 — see the prompt without spending anything

```bash
bin/run-loop.sh --dry-run
```

Read the output top to bottom. Notice it is just four things concatenated:
the **contract** (LOOP.md), the **skill** (what to do), the **current state**, and **live signals**.
That assembled string *is* the loop. There is no magic.

## Step 2 — run it for real

```bash
bin/run-loop.sh
cat STATE.md
```

The model read everything, decided what matters, and **rewrote STATE.md**. That rewrite is the
whole trick: a stateless model gets memory because the loop hands it last run's notes and saves
this run's notes.

## Step 3 — run it again

```bash
bin/run-loop.sh
```

Open `loop-run-log.md`. Two entries now. The second run saw the first run's `STATE.md` as input —
that's continuity. Items it already dismissed sit in *Noise / Ignore* so it doesn't re-litigate them.

## Step 4 — feel the cost gate

Edit `LOOP.md`, set `DAILY_TOKEN_CAP: 100`, run again. The gate refuses before calling the model.
Set it back to `100000`. This is the difference between a loop you trust unattended and one that
surprises you on the invoice.

## Step 5 — understand the ladder

You just ran **L1**: report only. It cannot edit code or touch git — by design. Read the
ladder in `LOOP.md`. You don't flip to L2 because you can; you flip after a week of L1 runs you'd
have signed off on, and only with the `loop-verifier` checker in place.

## The four ideas to keep

1. **The loop is a string you assemble**, not a framework. Contract + skill + state + signals.
2. **State is the spine.** No state file, no continuity, no loop — just repeated cold starts.
3. **Autonomy is earned in tiers.** Report → assist → unattended. Never skip a rung.
4. **Maker ≠ checker.** The thing that proposes a fix must not be the thing that approves it.

Next: read [`patterns/daily-triage.md`](patterns/daily-triage.md), then write your own skill in
`skills/` and point `run-loop.sh --skill your-skill` at it.
