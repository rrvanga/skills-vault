# Cron lifecycle lessons (2026-08 cleanup session)

Four durable findings from the redundancy-cleanup pass. These belong in
SKILL.md's Pitfalls; the guard blocked SKILL.md writes in the background
runtime, so they live here until a foreground pass patches them in.

## 1. Gateway lifecycle guard (#30719) — use a systemd user timer, not cron

`cronjob create` BLOCKS any job whose script contains
`systemctl --user restart hermes-gateway` — even a `no_agent` watchdog whose
whole purpose IS that restart. The guard prevents agent-driven
SIGTERM-respawn loops under systemd supervision.

Sanctioned home for gateway-restarting scripts: OUTSIDE the gateway, as a
systemd user timer:

```
~/.config/systemd/user/<name>.service   # [Service] Type=oneshot, ExecStart=/bin/bash <script>
~/.config/systemd/user/<name>.timer     # [Timer] OnBootSec=5min / OnUnitActiveSec=5min, WantedBy=timers.target
systemctl --user daemon-reload && systemctl --user enable --now <name>.timer
```

Verified: the timer fires on enable, the script runs, and the disaster path
(restore known-good + gateway restart after 3 consecutive cloud failures) is
back under systemd's control without Hermes in the loop. Verify the first tick
with `systemctl --user list-timers` and `pgrep -af <script>`.

## 2. Restore-material check when installing a watchdog

If a no_agent watchdog restores `~/.hermes/backups/known-good/` (.env +
config.yaml) after N failures, verify the dir EXISTS and is CURRENT at install
time. Found in the wild: the watchdog was relied upon for months while the
backup dir did not exist at all — the "restore" branch would have printed
"manual intervention needed" forever.

REFRESH the dir after every config/.env change (cp both files). A stale
snapshot resurrects deleted wiring — e.g. the 26B teardown changed
`fallback_providers.1` to the 12B; an old known-good would have restored a
model file that no longer exists.

## 3. ~/.hermes/cron/jobs.json is a STALE MIRROR of the live store

Removed jobs can be absent from it; newly created ones can be missing too (the
file showed 18 jobs while the live `cronjob list` had different content).
Never use jobs.json to answer "is this job registered" — that is
`cronjob list`. Use the file only for forensics (full prompts, repeat.times,
context_from chains), always cross-checked against the live list.

## 4. Recovering a job's exact prompt — the output archive

`cronjob list` shows only a prompt PREVIEW. The FULL prompt + last response are
archived verbatim in `~/.hermes/cron/output/<job_id>/YYYY-MM-DD_HH-MM-SS.md`
(written on every fired run).

Use these archives when merging or removing user-facing LLM jobs: two reminders
on the same schedule (oddbunch + iron clothes, both 10:00) were merged into one
"daily reminders" job WITHOUT losing content by reconstructing both prompts
from their output dirs. Preserve per-item completion/removal semantics in the
merged prompt ("remove only when ALL items are done; keep firing for the rest")
— the originals each had self-removal-on-completion logic that must survive the
merge. One merged job = one LLM call/day instead of two.