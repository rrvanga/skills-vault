# Hermes cron schedule inventory — this machine

Snapshot from `~/.hermes/cron/jobs.json` on 2026-09-05 (jobs.json `updated_at` 2026-09-05T07:21).
**Source of truth is jobs.json itself (per-job `schedule`, `enabled`, `last_run_at`, `next_run_at`).**
Re-read it before stating any schedule as fact; edit jobs only via the `cronjob` tool, never by hand.

20 jobs total.

## Agent jobs (LLM runs each tick)
- **Morning Brief** (`a0a8d90095ec`) — 07:00 daily · `morning_context.py` feeds context · deliver origin
- **daily-engineering-loop** (`26e42ff314c6`) — 09:00 Mon–Fri · autonomous engineering mission
- **til daily entry** (`3b8f77fe13ca`) — 10:30 Mon–Fri · public TIL note
- **Go adaptive monitor** (`81a8bc241220`) — 08:00–22:00 every 2h (even hours) · model-routing decisions
- **autonomy-window** (`75066396690b`) — 14:30 daily · autonomous work block
- **bot-bridge-watch** (`11e09d6a513c`) — every 2m · peer-bot message pump (git queue)
- **daily reminders** (`879e27ac4880`) — 10:00 daily
- **battery-band-monitor** (`f18d453cb6ee`) — every 360m · root battery-band watchdog report · deliver telegram
- **sleuth-judge-sweep** (`71217ad4cf99`) — every 360m · sleuth review layer (judge cron 6h)

## no_agent jobs (script output delivered verbatim; empty stdout = silent)
- **Token Usage Report** (`9e4d845884e6`) — 07:30 daily · `token_usage_report.py` · Go-dollar tracking
- **llmcost daily update** (`2785188c1081`) — 09:30 daily · `llmcost_update.sh`
- **awesome-local-ai daily drip** (`b999b6a17277`) — 10:00 daily · `awesome_drip.sh`
- **architecture diagram refresh** (`6f059ddea0d5`) — 11:00 daily · `architecture_diagram.sh`
- **Go bucket watchdog** (`a989f4620ad4`) — 08:00–22:00 every 2h (even hours) · `go_bucket_watchdog.py`
- **thermal-watch** (`e70270d8b772`) — every 5m · `thermal_watch.py` · CPU warn 92 / crit 95, 2-consecutive-sample sustained rule
- **skillspector weekly delta watch** (`9a5c5a983c6a`) — Monday 09:00 · `skillspector_watch.sh` · deliver telegram
- **skills vault sync** (`f8cbdde34dae`) — 09:45 daily · `skills_vault_sync.sh`
- **local-llm-backup-watchdog** (`17f0ef271f94`) — every 5m · `local_backup_watchdog.sh` · llama-server on-demand policy
- **daily-hermes-backup** (`7cbfaba35056`) — 06:30 daily · `hermes-backup-quick.sh`
- **cron-sentinel** (`9371802cb37a`) — 08:00 daily · `cron_sentinel.py` · NOTE: had never run as of 2026-09-05 (last_run_at null; first scheduled 08:00 that day)

## Delivery semantics reminder
`deliver` values here are 'origin' (this Telegram DM) unless noted. `no_agent` jobs: non-empty stdout → delivered; empty → silent; non-zero exit → error alert.
