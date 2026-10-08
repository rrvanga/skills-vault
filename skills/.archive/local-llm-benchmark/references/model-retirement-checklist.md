# Model / server retirement checklist (verified 2026-08, 26B teardown)

Retiring a local model means tracing every consumer BEFORE deleting anything —
the silent-breakage list. This is the exact sequence that worked when wiping
the 26B + pi stack and switching to the 12B-only setup.

## 1. Survey (read-only, before any kill/delete)

```bash
# Every llama-server instance — a watchdog-spawned TWIN on another port can be
# running unnoticed (found: 26B on :8080 AND a --fit on twin on :8081).
pgrep -af llama-server

# Configuration + script consumers of the model/port:
grep -niE '8080|8081|llama|<model-tag>' ~/.hermes/config.yaml
grep -n 'MODEL=' ~/.hermes/scripts/local_backup_watchdog.sh     # watchdog boot path
grep -rniE '<model>|pilm|pi-coding' ~/.hermes/scripts/          # exclude *.bak
# cron: cronjob action=list — look for jobs whose script mentions the model
```

## 2. Rewire BEFORE killing (order matters)

1. `hermes config set fallback_providers.N.model <new-model>` — a fallback
   pointing at the dying model goes brick the moment the server dies.
2. Watchdog `MODEL="..."` line → new GGUF path. If skipped, the watchdog boots
   a missing file family on the next cloud failure.
3. Registration files the harness owns (e.g. pi's `~/.pi/agent/models.json`).

## 3. Kill with an ANCHORED pattern

```bash
pkill -f '^/home/<user>/.local/llama-b10488/llama-server'   # carat + full path
```
`pkill -f 'llama-server -m …'` WITHOUT the `^` anchor matches the shell that
runs the pkill (its own cmdline contains the pattern) → SIGTERM kills your own
shell mid-script: exit -15, remaining commands never run, looks like a crash.

## 4. Delete + verify

- GGUF, companion drafts (`MTP/` = multi-token-prediction draft of the dead
  model), and server logs: `rm -v ~/models/<model>.gguf ~/models/server*.log`,
  `rm -rf ~/models/MTP`.
- Verify: `pgrep -af '^…/llama-server'` → none; `ss -tln | grep <port>` → free;
  `grep -rli <model-tag> ~/.hermes/scripts/ | grep -v '\.bak'` → clean;
  `ls ~/models/` → only the surviving model.
- Refresh `~/.hermes/backups/known-good/` (`cp .env config.yaml`) so the
  disaster watchdog restores the NEW wiring, not the deleted model's.
- The box keeps working with NO standing server: start-on-demand via the
  5m backup watchdog is the efficient end-state (no RAM/VRAM committed
  while the cloud is healthy).

## Pitfall footnotes from the teardown

- `rm -rf` a directory that is the shell's CURRENT cwd → exit 126 on every
  later command until you cd out. Pass `workdir=/tmp` (or cd) FIRST.
- The `--fit on` boot config measures 0.43 t/s (RAM spill) on the 12B — boot
  on-demand servers with the tuned flags (`-ngl N -ctk q8_0 -ctv q8_0
  -b 2048 -ub 512 -t 12 -tb 12 -sm none`), not `--fit on`.
- After teardown, update memory + the skill's Data/state so the next session
  doesn't describe a server that no longer stands.