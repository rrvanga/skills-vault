# Adaptive monitor — change-triggered agent pattern (monitor_script)

Worked example 2026-08-15: the 'Go adaptive monitor' cron (`adaptive_monitor.py`,
`~/.hermes/scripts/`, job `81a8bc241220`) — self-healing fallback wiring +
model-catalog tracking for the opencode-go LLM provider. Build time ~30 min.

## What it is

`monitor_script` runs FIRST each tick; its output is hashed as exact bytes.
UNCHANGED → the agent run is suppressed entirely (no LLM, no delivery — a silent
no_change tick). CHANGED → a MONITOR CHANGE DETECTED block (unified diff + new
output) is injected, then a normal agent run follows. The FIRST tick always runs
the agent (baseline). Zero-cost self-healing: detection is free, reasoning +
action happen only on real change (fallback model died, catalog gained models).

## Stable-output design rules (violations false-fire the agent every tick)

- No timestamps, no volatile ordering: sort lists, fixed line prefixes.
- Normalize transient failures to a STABLE string (e.g. `fetch=FAIL`) so a
  network blip never reads as a change; only real data diffs change the hash.
- Health checks: ping candidates in preference order, emit the first healthy
  result (e.g. `fallback=nemotron-3-ultra-free`); the line flips only on an
  actual health change, and its value doubles as the recommended config.
- Test hooks: env-var overrides for endpoints (`ADAPT_ZEN_URL`, `ADAPT_CHAT_URL`)
  so failure paths are exercisable without touching the network.
- Verify stability: run the script twice — byte-identical output proves it.
  Force a failure (dead endpoint env) — stable `fetch=FAIL` string, exit 0.

## Agent prompt structure (self-contained; fresh session every fire)

- Restate the state-line semantics (what each prefix means, incl. `fetch=FAIL`
  = "transient, do nothing").
- Key facts inline: config paths, how to re-wire (`hermes config set`), the
  verification command (`hermes config get`), what NOT to touch.
- IF change block: diagnose the diff by line prefix, then per-line actions —
  re-wire config + verify; test alternates before switching; price new entities
  by sibling analogy with a `# GUESS` marker; update the governing skill
  reference; ≤ ~10-line report.
- IF no change block (baseline): reply briefly, modify NOTHING.
- Bounds: cap tool calls (~15), conservative actions, never echo secrets.

## Gotchas hit while building

- opencode.ai's edge 403s the default `Python-urllib` UA; a browser UA passes
  (curl's default UA also passes). Hardcode a Chrome UA in the fetch.
- The API key is not exported into the cron scheduler env — the script parses
  `~/.hermes/.env` itself (regex on `KEY=value`), never prints it.
- Ping = 1-token `chat/completions` (HTTP 200 = healthy); timeout each ping so
  a dead upstream can't stall the whole tick.
- `enabled_toolsets` on the job: restrict to what the acting agent needs
  (e.g. `["web","terminal","file"]`) to cut per-fire token overhead.

## Verification done before going live

- Stability: two runs byte-identical ✓
- Failure path: dead endpoint → `fetch=FAIL`, exit 0, still stable ✓
- Health flip: dead chat endpoint → `fallback=ALL-DEAD` (would fire agent) ✓
- Live fire: `cronjob action=run` → baseline agent ran, modified nothing,
  reported state, delivery landed ✓ (baseline changed nothing on purpose)
