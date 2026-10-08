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

## 2. Built-in backup layers & the layer-audit rule

The built-in layer (v0.21+) is `hermes backup`: full zip of the config, skills, sessions,
data — codebase excluded (git-managed) — or `--quick` for the critical state
(config, state.db, .env, auth, cron). Default output `~/hermes-backup-<timestamp>.zip`;
archives are plaintext and hold secrets — keep 600. `hermes update --backup` runs a full
built-in backup before updating → `~/.hermes/backups/pre-update-<ts>.zip`; use that flag
for every self-update. A restore/import path ships in the same CLI.

The custom agent-lab layer (encrypted daily tarballs → `~/.hermes-backups/`) adds what the
built-in zip does not: GPG AES-256 at rest; sqlite `.backup` snapshots with a busy timeout
(never tar a live `.db`/`-wal`/`-shm` set — a torn WAL silently corrupts the archive);
retention pruning that deletes old archives only after the new one decrypts and lists
clean; passphrase kept out-of-band (mode-600 file, separate from the archive) so a fresh
machine can still decrypt.

**Layer-audit rule — a documented backup layer is not a live one.** Before trusting ANY
layer, verify (1) its schedule still exists in `~/.hermes/cron/jobs.json` — jobs vanish
silently while old archives stay on disk; (2) the deployed script matches its repo source
(`cmp` — deployed copies drift after repo edits); (3) the newest archive is fresh
(`ls -lt ~/.hermes-backups/`); (4) the restore helper exists — it may never have been
deployed. Also: "backup" in a job name can mean fallback inference, not data —
`local-llm-backup-watchdog` watches the :8081 local-LLM server, it archives nothing.

## 3. Temp cleanup (`/tmp` hygiene)

Hermes leaves artifacts in `/tmp` (tool-call dumps in `hermes-results/`, env snapshot
scripts `hermes-snap-*.sh`, `node-compile-cache`). The snap scripts are **plaintext env
dumps in a world-readable dir** — a credential smell; delete them.

Safe delete set: `/tmp/hermes-results`, `/tmp/hermes-snap-*.sh`, `/tmp/node-compile-cache`.
**Never touch** system-owned entries: `.X11-unix`, `.ICE-unix`, `sddm-*`, `plasma-*`,
`systemd-private-*` (they belong to the session manager/services). `~/.hermes/cache/` is
regenerable but tiny and useful (tool-discovery cache) — leave it.

## 4. Zero-token cron jobs (no_agent pattern)

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

## 5. Updating Hermes safely (self-update lifecycle)

- Always run `hermes update --backup`: the flag forces the built-in full backup (the
  `pre-update-*.zip` under `~/.hermes/backups/`) before any change lands — that zip is the
  rollback path for full data.
- Run the update in the background with notify; it takes minutes (git fetch phase + 8-10
  min pip install). Mid-flight health check: `ps -eo pid,ppid,etime,%cpu,comm | awk
  '$1==<pid> || $2==<pid>'` + `pgrep -P <pid> -a` — a busy `hermes` child at ~10%+ CPU is
  working, not hung; long pip installs are normal.
- The gateway restarts drain-first: it waits for the in-flight turn to finish, so the
  conversation rides through on the new build — do not kill the session or retry mid-update.
- After the update, the background-process record is GONE from the process manager — the
  gateway restart reaped it; that is the completion signal, not an error. Verify instead:
  `ps -p <pid>` gone, `systemctl --user show hermes-gateway -p
  ActiveState,SubState,ExecMainStartTimestamp` (fresh restart timestamp), `hermes --version`
  and `pip show hermes-agent` (new version, rebuilt egg-info).
- Grep the real repo layout: `~/.hermes/hermes-agent` has NO `src/` — code lives in
  `agent/`, `hermes_cli/`, `providers/`. A "0 hits" baseline against `src/` is a false
  negative.
- Verify fixes in the INSTALLED build (venv python import, read the installed file), not
  just the git tree — HEAD can be ahead of what the gateway runs until pip install and
  restart complete.
