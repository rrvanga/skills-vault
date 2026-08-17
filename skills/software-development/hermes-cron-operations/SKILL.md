---
name: hermes-cron-operations
description: Use when creating or fixing Hermes cron jobs.
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [hermes, cron, scheduling, automation, watchdog, no-agent]
---

# Hermes cron operations

## When to Use

Any task involving the `cronjob` tool: create/update/pause/remove/list scheduled
jobs, wire a script to a schedule, build a watchdog or briefing, resume work after
a gateway restart, or diagnose "job didn't fire / fired wrong / fired empty".

## Job anatomy (the fields that matter)

- `schedule`: `'30m'` / `'every 2h'` / cron expr `'0 9 * * 1-5'` / ISO one-shot.
  `next_run_at` in `cronjob list` confirms registration.
- `no_agent` (default false): LLM-driven agent job (the prompt runs each tick)
  vs script-only job. `no_agent=True` IGNORES prompt/model/skills — the script
  IS the job; set it for anything with fixed output shape (watchdogs, reports,
  backups, pollers).
- `script`: bare filename relative to `~/.hermes/scripts/` — absolute paths
  rejected, symlinks resolving outside the dir rejected (see Pitfalls).
- `deliver`: omit = current chat/topic; `'origin'` = creating chat; `'local'` =
  file only; `'all'` = every connected home channel; `platform:chat_id[:thread_id]`
  = specific target (`platform:chat_id` alone loses topic targeting).
- `enabled_toolsets`: restrict to what the prompt needs (e.g. `["file"]`) —
  big input-token savings on agent jobs that only read files.
- `attach_to_session`: recurring job becomes continuable (user replies to its
  delivery and the agent has the brief in context instead of asking "what?").
- `context_from`: inject another job's most recent output (chained jobs).
- `skills`: attach skills to an agent job; they load in order before the prompt.

## no_agent delivery semantics (the watchdog contract)

- Non-empty stdout → delivered verbatim as the message.
- Empty stdout → SILENT: nothing sent, nothing user-visible happened.
- Non-zero exit / timeout → error alert (a broken watchdog can't fail silently).
- Design scripts: quiet unless there's something to report; on failure print a
  clear message and exit non-zero.

## Agent-job rules

- Prompts must be SELF-CONTAINED — each tick is a fresh session with no chat
  context; state lives in files, repos, or `context_from` outputs.
- Agent runs have iteration/time budgets: long steps (builds, multi-model review
  gates, 10-min CLI calls) must launch in BACKGROUND EARLY with full output
  redirected to a file, then be polled while other work proceeds. A foreground
  long call can burn the whole budget and end the run with partial state.
- If the run is about to hit the ceiling, deliver a precise partial status
  (what passed, what's left, exact next commands) so the next run or the user
  finishes mechanically.
- Cron sessions must not recursively schedule cron jobs (safety rule).

## Pitfalls

- **`repeat` is sticky on update**: converting a one-shot job to a cron schedule
  with `cronjob update` PRESERVES the old `repeat: {times: 1}` — the job will
  auto-delete after one more fire unless you pass `repeat` explicitly. Pass
  `repeat=0` (normalized to `None` = forever) for "keep running until removed".
  Verify with `cronjob list` (should show `repeat: "forever"`, not `"1/1"`) or
  read `repeat.times` from `~/.hermes/cron/jobs.json` (`None` = infinite).
- **Script path guard**: `cronjob create` rejects anything escaping
  `~/.hermes/scripts/`. Absolute paths rejected; SYMLINKS whose target resolves
  outside the dir are rejected too ("Script path escapes the scripts directory
  via traversal"). Deploy cron scripts as REAL FILE COPIES (as the existing
  scripts in `~/.hermes/scripts/` are), and re-copy after upstream repo changes.
- **Sandbox-green ≠ production-ready**: before wiring a cron to the LIVE
  environment, verify the real prerequisites exist — secret/passphrase files
  (mode-checked), config dirs, deploy paths, script copies. A pipeline that
  passed sandbox tests dies on day one if the passphrase file was never created.
- **Lifecycle guard interplay**: cron-agent sessions hit the same lifecycle
  guard as interactive ones — python file-access calls in terminal commands
  (`open(`, `Path(`, `read_text(`, `write_text(`) are hardline-blocked; use the
  write_file/read_file tools or stdin redirects instead.
- **Stale run metadata**: `last_run_at: null` does NOT mean broken. A job created after its last scheduled tick legitimately shows null, no output dir (dirs appear at `~/.hermes/cron/output/<job_id>/` only after a fire), and a next_run in the future. Before declaring a miss: read the FULL record from `~/.hermes/cron/jobs.json` (compare `created_at` against the schedule's tick times — one-line python json dump of the job id), check `~/.hermes/cron/executions.db`, and cross-check that OTHER jobs have output dirs (proves the scheduler ticks). Null + no output + created_at after the last tick = healthy, first fire next tick.
- **One-shot resume after a gateway restart**: restart-dependent work follows
  the schedule-ahead pattern — a one-shot cron resumes the work after the
  restart, then the schedule is cleaned up.
- **Watchdog script robustness**: silent-unless-breach, size sanity check after
  fetch, dedupe, all-tokens matching, never-silent-fail. Full recipe: the
  web-price-research skill's price-watchdog reference file.
- **Human-readable output**: for report jobs, merge duplicate provider/endpoint
  rows, round to K/M units, keep only meaningful numbers, drop four-decimal
  costs — the user reads these at 07:30, not a debug console.

## Verify

- `cronjob list`: name, schedule, `last_status: ok`, sane `next_run_at`.
- Scripts: run once manually in the same environment the cron uses; confirm
  exit code AND stdout semantics (empty = silent, non-empty = delivered).
- Agent jobs: read the delivered output / `~/.hermes/cron/output/<job_id>/` —
  "completed" is not the same as "did the work".
