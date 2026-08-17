# Safe keeping, temp cleanup & zero-token cron jobs

Verified on <REDACTED>'s machine 2026-08. Two reusable procedures plus the cron pattern that
keeps reporting at zero LLM cost.

## 1. Safe keeping (consistent backup before config surgery)

Goal: a single tarball of the Hermes home that survives a bad config edit, with a
*consistent* SQLite snapshot (not a racy `cp` of a live DB).

```bash
mkdir -p ~/backups
# consistent snapshot via SQLite backup API (safe while gateway is running)
python3 -c "
import sqlite3, os
s = sqlite3.connect(os.path.expanduser('~/.hermes/state.db'))
d = sqlite3.connect(os.path.expanduser('~/backups/state.db.stage'))
s.backup(d); d.close(); s.close()
"
TS=$(date +%Y%m%d-%H%M%S)
tar czf ~/backups/hermes-state-$TS.tar.gz \
  -C ~/.hermes config.yaml SOUL.md .env \
  -C ~ .hermes.md \
  -C ~/backups state.db.stage --transform 's/state.db.stage/state.db/' \
  -C ~/.hermes memories skills cron scripts channel_directory.json 2>/dev/null
chmod 600 ~/backups/hermes-state-$TS.tar.gz
rm ~/backups/state.db.stage
gzip -t ~/backups/hermes-state-$TS.tar.gz   # integrity check
tar tzf ~/backups/hermes-state-$TS.tar.gz | grep -E '^\.env$|^config\.yaml$|^state\.db$'  # verify the criticals
```

### Pitfalls (all hit in practice)
- **`.env` lives at `~/.hermes/.env`, NOT `~/.env`.** A `-C ~` tar with `.env` silently
  drops it (file not there) — then the archive looks fine but the key is missing. Always
  `grep '^\.env$'` the archive listing before trusting it.
- Tar order matters: `-C` applies per-file-group; put the `--transform` before the group
  it applies to.
- The whole tarball must be `chmod 600` — it contains the API key.
- `tar czf ... 2>/dev/null` hides missing-file warnings; use the `tar tzf | grep` step as
  the real verification, or drop the redirect and check stderr.

## 2. Temp cleanup (`/tmp` hygiene)

Hermes leaves artifacts in `/tmp` (tool-call dumps in `hermes-results/`, env snapshot
scripts `hermes-snap-*.sh`, `node-compile-cache`). The snap scripts are **plaintext env
dumps in a world-readable dir** — a credential smell; delete them.

Safe delete set: `/tmp/hermes-results`, `/tmp/hermes-snap-*.sh`, `/tmp/node-compile-cache`.
**Never touch** system-owned entries: `.X11-unix`, `.ICE-unix`, `sddm-*`, `plasma-*`,
`systemd-private-*` (they belong to the session manager/services). `~/.hermes/cache/` is
regenerable but tiny and useful (tool-discovery cache) — leave it.

## 3. Zero-token cron jobs (no_agent pattern)

Token-usage reporting and pure data jobs can run with **no LLM at all**:

- `cronjob create` with `no_agent: true` + `script: ~/.hermes/scripts/<name>.py` —
  the script's stdout is delivered verbatim; zero tokens, no agent loop.
- Data source for usage: `~/.hermes/state.db` table `session_model_usage` (columns:
  `model, billing_base_url, billing_provider, api_call_count, input_tokens, output_tokens,
  cache_read_tokens, cache_write_tokens, reasoning_tokens, estimated_cost_usd,
  first_seen, last_seen`). Group by `model`/`billing_base_url` to see which provider
  burned tokens (this caught LiteLLM routing 2.3M input tokens vs 211k direct).
- For LLM-summarized briefs: `script:` (data collector) + agent prompt — script stdout is
  injected as context; keeps the LLM cheap because it only formats, doesn't fetch.
- Cron jobs are stored in `~/.hermes/cron/` (jobs.json, executions.db, output/<job_id>/),
  NOT in state.db — `sqlite3 .tables` shows no cron tables.
- `cronjob action=run` fires a manual test run in the background; the result lands in
  `~/.hermes/cron/output/<job_id>/<timestamp>.md`.
- A cron run that reports "nothing new" should emit exactly `[SILENT]` to suppress delivery.
