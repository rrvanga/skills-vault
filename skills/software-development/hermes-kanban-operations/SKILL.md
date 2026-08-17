---
name: hermes-kanban-operations
description: Use when enabling or driving the Hermes kanban board.
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [hermes, kanban, orchestration, background, gateway, dispatcher, workers]
---

# Hermes kanban board operations

## When to Use
Any request to enable the kanban board, create/assign/dispatch/promote tasks, track multi-agent work, or debug why a task isn't being picked up. The board is Hermes's durable multi-profile/multi-worker queue: tasks persist in SQLite, the gateway hosts an embedded dispatcher that spawns worker sessions per assigned profile.

## Model (30-second mental map)
- **Board** = SQLite DB at `~/.hermes/kanban.db`. One or more boards (default: `default`); one or more profiles can be assignees (`default` is the only one on a single-profile box).
- **Task** = a card. Lifecycle: `ready` → `running` → `complete` / `failed` / `blocked`.
- **Dispatcher** = embedded in the **gateway** process. Ticks every `kanban.dispatch_interval_seconds` (default 60s). It claims `ready` tasks and spawns a **worker**: a fresh `hermes` session for the assignee profile that loads the task's `--skill` (if any) and executes the `--body` as its prompt.
- **Worker output** = written back to the task on completion; with `kanban.auto_subscribe_on_create: true` the creator gets the completion delivered to their home channel (Telegram DM here).

## Enable & first use (verified this session)
```bash
hermes kanban init                 # creates ~/.hermes/kanban.db; lists discovered profiles; prints "start the gateway" hint
systemctl --user is-active hermes-gateway   # dispatcher only runs if the gateway is up
hermes kanban boards list          # confirm board exists
hermes kanban create \
  --assignee default \
  --skill linux-system-audit \
  --priority 10 \
  --body '...multiline task prompt...' \
  "Task title"                     # returns: Created t_xxxxx (ready, assignee=default)
```
No gateway restart is needed if it's already running — the dispatcher is already embedded (`kanban.dispatch_in_gateway: true`). If the gateway is down, `ready` tasks sit forever; start it with `hermes gateway start` (never `hermes gateway restart` — see the lifecycle-guard note in memory).

## CLI verbs (quick reference)
- `hermes kanban init` — create the board DB.
- `hermes kanban boards list` / `boards select <slug>` — manage boards.
- `hermes kanban list` — show all tasks on the current board (status, assignee, title).
- `hermes kanban show <task_id>` — full detail: status, assignee, workspace, skills, body, event timeline, run history.
- `hermes kanban create [flags] "Title"` — flags: `--assignee <profile>`, `--skill <name>`, `--priority <n>`, `--body '<text>'`, `--initial-status {blocked,running}`, `--workspace {scratch|dir:<path>|worktree:<branch>}`.
- `hermes kanban promote <id>` — move a `todo`/`blocked` task to `ready` (manual dispatch recovery).
- `hermes kanban complete <id>`, `kanban block/unblock <id>`, `kanban archive <id>`, `kanban assign <id> <profile>`, `kanban link/unlink`, `kanban comment <id> <text>`, `kanban tail <id>`.

## Dispatcher config (via `hermes config get kanban`)
Key keys and defaults seen on this box: `dispatch_in_gateway: true`, `dispatch_interval_seconds: 60`, `auto_subscribe_on_create: true`, `review_dispatch: true`, `auto_decompose: true`, `auto_decompose_per_tick: 3`, `failure_limit: 2`, `dispatch_stale_timeout_seconds: 14400`, `reconcile_orphans: true`, `done_sub_retention_days: 30`, `max_in_progress_per_profile: null`, `default_assignee: ''`, `orchestrator_profile: ''`, `worker_log_rotate_bytes: 2097152`.

## Pitfalls (all hit or confirmed this session)
1. **`create` defaults to `ready`, NOT a parked state.** There is no default `todo`; the moment you create a card it's dispatchable and the gateway claims + spawns a worker on the next tick (≤60s). `--initial-status` only accepts `blocked` or `running`.
   **VERIFIED GOTCHA (2026-08-16): `--initial-status blocked` alone does NOT stick.** `create` writes only a `created` event with `status: blocked` in its payload — no `blocked` event row. `recompute_ready()` in `hermes_cli/kanban_db.py` (line ~4473) considers a task sticky-blocked only when `_has_sticky_block()` (line ~4406) finds a `blocked` event row; with none, it treats the card as circuit-breaker-recoverable and **auto-promotes it to `ready` on the next dispatcher pass** (observed: created 00:41:40 → `promoted` event 00:41:43 → would have been spawned as a worker).
   **The safe staging recipe: create with `--initial-status blocked`, then IMMEDIATELY `hermes kanban block <task_id>`** (writes the sticky `blocked` event), then verify with `hermes kanban show <task_id>` that status is `blocked`. Only sticky-blocked cards are safe to park; promote with `hermes kanban promote <id>` (or `unblock`) when actually due. If you skip the second `block`, the card silently goes `ready` within a minute — dangerous for approval-gated work.
2. **Scratch workspaces are ephemeral.** A task created without `--workspace` gets a `scratch` workspace that is **deleted on completion** (the worker logs a `tip_scratch_workspace` warning). The task's *report* survives on the task record, but any artifact files do not. For deliverable work, use `--workspace dir:/abs/path` (existing dir) or `--workspace worktree:<branch>`.
3. **`hermes kanban tail <id>` defaults to follow-mode** — it streams until Ctrl-C, so it hangs under a bounded tool timeout (60s → exit 124). For a bounded snapshot, read the worker log file directly instead: `~/.hermes/kanban/logs/<task_id>.log` (via `read_file`). Use `tail` only when you actually want live streaming.
4. **Workers can't ask the user anything.** A dispatched worker runs autonomously in a fresh session. The `--body` must be fully self-contained, and for anything sensitive it must carry an explicit "read-only / do NOT apply changes without approval" contract so an autonomous worker can't make destructive changes (see Blast-radius below).
5. **Emoji in `--body` trips a benign security flag.** ✅/⚠️ etc. contain Unicode variation selectors, which triggers a MEDIUM "variation selector characters detected" security-scan flag. It auto-approves (smart approval), so it's harmless — but keep emoji out of `--body` if you want clean, unflagged commands.
6. **The dispatcher lock is `slick:<gateway-pid>`.** Task `show` events reveal `claimed {'lock': 'slick:197560'}` + `spawned {'pid': ...}` — that's the gateway's embedded dispatcher doing its job, not an error.
7. **Workers: the `kanban_complete` tool may NOT be exposed in the worker session.** If the protocol warning fires but no `kanban_complete`/`kanban_block` tool exists in the toolset, use the CLI: `hermes kanban complete <id> --result "$(cat /tmp/report.txt)" --metadata '{"key":"value"}'` (flags: `--result` report text, `--summary` structured handoff, `--metadata` JSON facts; `--result` applies to all ids, summary/metadata are per-call). Write the report to /tmp first and pass via command substitution to avoid quoting blowups. Then verify with `hermes kanban show <id>` — status must flip to `done`.
8. **Scratch-workspace deletion breaks the session cwd.** On completion the workspace dir is removed while the worker shell still sits in it; every subsequent `cd`/relative command fails with `getcwd: No such file or directory`. Always run post-completion verification with an explicit `workdir` (e.g. `/home/<user>`) and never rely on `cd` after `complete`.

## Blast-radius pattern for sensitive tasks (remediation, firewall, sshd, cron)
Scope the `--body` as: (1) run the audit/review read-only, (2) verify anomalies in BOTH directions, (3) report ✅/⚠️ by severity with footnotes, (4) propose fixes in two batches — A) needs-sudo exact commands for the user, B) agent-executable pending explicit green light, and (5) **do NOT apply changes without approval**. This keeps an autonomous worker from mutating system/security state while still delivering a complete audit. The `linux-system-audit` skill already encodes this contract — pass it via `--skill linux-system-audit` for machine audits.

## Verification
- After `create`: `hermes kanban list` shows the card; `hermes kanban show <id>` shows `status: running` + a `spawned {'pid': ...}` event within ~60s of reaching `ready`.
- Worker progress: `read_file ~/.hermes/kanban/logs/<task_id>.log` (bounded), or `hermes kanban tail <id>` for live follow.
- Completion: task flips to `complete`, and (with auto-subscribe) the report lands in the origin chat.

## Related
- `hermes-cron-operations` — the other half of Hermes background scheduling (time-triggered, not queue-triggered).
- `hermes-agent` (bundled) — its `background-systems.md` reference is the authoritative design doc for the board + dispatcher; treat it as source of truth when the two differ.
