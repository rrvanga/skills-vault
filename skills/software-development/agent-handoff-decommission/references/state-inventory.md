# What a Hermes agent persists (inventory recipe)

Read-only counters for a handoff brief. Never `cat .env` — count keys with
`grep -c '^KEY='`.

```bash
H=~/.hermes
ls -l "$H"/memories/*.md                                   # MEMORY.md, USER.md + sizes
find "$H/skills" -name SKILL.md | wc -l                    # skills; break out .archive separately
find "$H/skills" -path '*references/*' -type f | wc -l      # reference depth
find "$H/skills" -path '*scripts/*' -type f | wc -l
sqlite3 "$H/state.db" "select count(*) from sessions; select count(*) from messages;"
sqlite3 "$H/kanban.db" "select status, count(*) from tasks group by status;"
du -h "$H/state.db" "$H/kanban.db" "$H/logs" | tail -3
find ~/obsidian-vault -name '*.md' | wc -l                 # knowledge-base notes
ls -1 "$H/plans" 2>/dev/null                               # dated plans
ls -1 "$H/cron/output" | wc -l                             # jobs that have ever fired
```

## Stores and their role

| Store | Path | Role |
|---|---|---|
| Memory | `memories/MEMORY.md`, `USER.md` | always-injected facts; hard char budget |
| Skills | `skills/**/SKILL.md` | procedural memory, loaded on trigger |
| Transcripts | `state.db` | sessions + messages + FTS index; the audit trail |
| Compaction | inside sessions | lossy handoff blocks; never the source of truth |
| Cron | `cron/jobs.json` + `executions.db`, `deliveries.db`, `notepad.db`, `output/` | schedules, prompts, run history |
| Kanban | `kanban.db` | durable multi-session work queue |
| Knowledge base | `~/obsidian-vault` | human-readable notes, decisions journal |
| Plans | `.hermes/plans/`, per-repo `.hermes/plans/` | dated design docs, no execution |
| Bot bridge | `bridge-repo/` | cross-agent git queue |
| Backups | `backups/known-good/`, `backups/broken_state/`, `state-snapshots/` | restore sources — verify freshness; a stale known-good is fault injection |
| Logs | `logs/` + journald units | post-mortems |
| Docs | `~/dev/<repo>/docs/` | architecture, mission, runbooks |

## Config and secrets

- `config.yaml` — model/provider, toolsets, platforms. Edit via `hermes config set` only.
- `.env` — every credential. Report key names and count, never values.
- `profiles/<name>/` each carry their own `.env`; a platform token shared across profiles
  is a 409 collision waiting for the first one to gate up. Report it as a risk.
