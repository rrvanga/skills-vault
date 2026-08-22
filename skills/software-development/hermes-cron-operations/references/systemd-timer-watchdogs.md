# Watchdogs that restart the gateway: systemd timer, not Hermes cron

## The guard (proven 2026-08)

`cronjob create` REFUSES scripts containing gateway lifecycle commands
(e.g. `systemctl --user restart hermes-gateway`) — smart-approval guard #30719
prevents agent-driven SIGTERM-respawn loops. Error message suggests running the
script "from a shell outside the running gateway". Do not fight it; that is the
correct protection.

## The sanctioned home: a systemd USER timer

A gateway-restarting watchdog runs OUTSIDE the gateway as a systemd user unit:

`~/.config/systemd/user/llm-watchdog.service`:
```
[Unit]
Description=... (disaster path: restore known-good + restart gateway after N failures)
After=hermes-gateway.service

[Service]
Type=oneshot
ExecStart=/bin/bash /home/<user>/.hermes/scripts/llm-watchdog.sh
```

`~/.config/systemd/user/llm-watchdog.timer`:
```
[Unit]
Description=Run every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

Wire-up + verify:
```bash
systemctl --user daemon-reload
systemctl --user enable --now llm-watchdog.timer
systemctl --user list-timers | grep llm-watchdog   # NEXT run visible
# first tick fires immediately on enable --now; watch the script run:
#   systemctl --user status llm-watchdog.service   (oneshot exit code)
```

Design notes: `Type=oneshot` + a script that is silent-when-healthy matches the
no_agent cron contract (empty stdout = nothing to report; nonzero exit = alert).
The timer unit pair survives reboots only with `loginctl enable-linger <user>`
(already in place here). The script must be self-contained (absolute paths; cron
and systemd both start with $HOME set, but do not rely on interactive env).

## Pitfall: killing processes with pkill

`pkill -f 'llama-server'` matches YOUR OWN shell's cmdline (the pattern text is in
the `bash -c` string) → the command SIGTERMs itself, exit -15, and subsequent
statements never run. Anchor the pattern to the binary's absolute path:
```bash
pkill -f '^/home/<user>/.local/llama-b10488/llama-server'
```
`^` — the daemon's cmdline starts with the full binary path; your shell's does not.
The same footgun applies to any `pkill -f`/`pgrep -f` on a pattern your command
text contains.

## Related

- Known-good snapshot: the disaster script restores `~/.hermes/backups/known-good/`
  (.env + config.yaml, mode 600). REFRESH it after every material config change —
  a restored snapshot that predates the current wiring resurrects old state.
- Same 5m cadence + silent-when-ok as Hermes cron watchdogs; two cloud probes at
  5m (local-backup + disaster) is acceptable duplication — different actions
  (boot local vs restore config).