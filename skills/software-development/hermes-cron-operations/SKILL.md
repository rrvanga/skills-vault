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
schedule, wire a script to a schedule, build a watchdog or briefing, resume work after
a gateway restart, or diagnose "job didn't fire / fired wrong / fired empty".

## This machine's standing schedule

A snapshot of this host's active jobs lives in `references/schedule-inventory.md`
(job name, id, schedule, script, delivery) — use it for ORIENTATION, not authority.
**Source of truth is `~/.hermes/cron/jobs.json`** (per-job `enabled`, `schedule`,
`last_run_at`, `next_run_at`). Re-read jobs.json before stating any schedule as
fact, and edit jobs only via the `cronjob` tool. Jobs were being created/edited
recently (updated_at ticks on every run), so never trust a stale snapshot.

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
- **Change-gating suppresses RUNS, not deliveries**: a `monitor_script` agent
  job skips the LLM when the hash is unchanged, but ANY change fires the agent
  and its reply is delivered verbatim. A benign self-healed change (fallback
  recovered, model removed, verification passed) is NORMAL operation — the
  prompt must end such ticks by replying with exactly `[SILENT]`, the built-in
  delivery-suppression marker (scheduler `SILENT_MARKER` /
  `_is_cron_silence_response`; accepted as whole response, first/last line, or
  bare `SILENT`/`NO_REPLY`). Reserve loud reports for genuine anomalies:
  ALL-DEAD with no recovery, a newly priced paid model, an action the user
  must know about. Never rely on hash-gating alone to keep a monitor quiet.
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

- **`hermes backup -q` ≠ a zip file**: quick mode writes a labeled snapshot DIR under `~/.hermes/state-snapshots/<UTCts>-<label>/` (restore = in-session `/snapshot restore <id>`); `-o`/`-l` zip flags are ignored with `-q`. Built-in auto-prunes globally to keep=20 (rmtree) and the updater sets keep=1 at update time. Scripts that expect a .zip will falsely report failure even though the CLI exited 0 — verify by snapshot presence (newest `*-<label>` dir), not output path.
- **Verifying a silent-on-normal prompt made it into the job**: after
  `hermes cron edit <job_id> --prompt "$(cat /tmp/prompt.txt)"` (write the new
  prompt to a temp file first — long multiline prompts with backticks survive
  command substitution cleanly), confirm the edit landed by dumping the job's
  stored prompt from `~/.hermes/cron/jobs.json` (one-line python) and asserting
  the marker count (`[SILENT]` occurrences) and absence of the old mandate
  string. A successful `cron edit` exit code does not prove the new text is
  the one stored.

- **`hermes cron doctor` ALWAYS exits 0**: findings print to stdout ("Cron doctor found N issue(s)…") but the CLI rc is swallowed — never gate a wrapper on doctor's return code; parse stdout ("no issues" = clean). Verified 2026-09-05.
- **Dormancy sentinel — house pattern for "job silently not running"** (`~/.hermes/scripts/cron_sentinel.py`): a no_agent script job (every 6h) that runs the built-in `hermes cron doctor` (failed runs, overdue `next_run_at` beyond 15 min grace, delivery/config issues) AND diffs live job ids against `~/.hermes/cron/.cron-sentinel-baseline.json`, alerting (message + exit 1) when an expected job vanishes from jobs.json — the classic silent-dormancy case doctor can't see (it only iterates CURRENT jobs). Silent on normal; baseline auto-seeds on first run; a removed job alerts exactly once, then the baseline adopts the new set (intentional removals self-confirm).

## Verify

- `cronjob list`: name, schedule, `last_status: ok`, sane `next_run_at`.
- Scripts: run once manually in the same environment the cron uses; confirm
  exit code AND stdout semantics (empty = silent, non-empty = delivered).
- Agent jobs: read the delivered output / `~/.hermes/cron/output/<job_id>/` —
  "completed" is not the same as "did the work".
