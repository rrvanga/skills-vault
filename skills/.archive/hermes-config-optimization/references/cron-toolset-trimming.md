# Per-job cron toolset trimming (token savings — proven 2026-08-21)

Every enabled tool injects its schema into the system prompt on EVERY cron run; small
LLM jobs (reminders, daily writers) were carrying the full toolset. Per-job
`enabled_toolsets` is an ALLOWLIST applied at fire time — the scheduler layers it under
the global `disabled_toolsets`, and three toolsets are always disabled in cron context
(source: ~/.hermes/hermes-agent/cron/scheduler.py `_resolve_cron_disabled_toolsets`).

## Applying it

`cronjob update <job_id>` with `enabled_toolsets=["<toolset>", ...]` — the update
response echoes the field; confirm it before moving on.

Authoritative toolset names (from the official docs): `web`, `search`, `terminal`,
`file`, `browser`, `vision`, `image_gen`, `skills`, `tts`, `todo`, `memory`,
`session_search`, `cronjob`, `code_execution`, `delegation`, `clarify`,
`homeassistant`, `messaging`, `spotify`, `discord`, `discord_admin`, `debugging`,
`safe`.

## Verified-safe trims (examples from this box)

| Job | Toolset | Why it's sufficient |
|---|---|---|
| daily reminders (self-removing) | `["cronjob"]` | only ever calls cronjob list/remove on completion |
| TIL daily entry | `["file","terminal"]` | writes the entry + git commit/push |
| Go adaptive monitor | `["terminal","file"]` | rewrites fallback via `hermes config set`, reads monitor output |

## Keep FULL toolsets on

- Autonomous work loops (daily-engineering-loop, autonomy-window) — their task is
  undefined ahead of time; a job without its tool is a broken job.
- Any job whose needs are uncertain (e.g. the morning brief, which may reach for
  memory/session_search) — the token cost of the full set is far smaller than a
  silently failing flagship job.
- `no_agent=true` script jobs (watchdogs, price watchers): no LLM runs at all, so
  toolsets are irrelevant there.