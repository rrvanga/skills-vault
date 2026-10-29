# Watchdog restart loops & false-disaster restores

Symptom class: a service (agent gateway, daemon, server) restarts on a fixed cadence and never stays up; config files keep reverting to old values; "it was offline for days".

## Triage order (all read-only)

1. `systemctl --user list-timers --all --no-pager` — find the timer whose ACTIVATES column points at a watchdog that touches the target.
2. `journalctl --user -u <target-unit> --since <date> | grep -E "Started|Stopped|Scheduled restart|Main process exited"`, then count starts per day. A constant gap (same minutes-offset every time) is a scheduler, not a crash: `jq`/awk the timestamps and diff consecutive pairs.
3. `systemctl --user cat <watchdog>.service` → read the script it runs; the restore/restart branch is the suspect.
4. Error census from the watchdog's own journal: `grep -oE "HTTP [0-9]{3}" | sort | uniq -c`, then bucket by day. 401 = credential rejected, 400/404/410 = identifier retired/unknown, 000/timeout/5xx = transport. Only the last is an outage to fail over on.
5. `ls ~/.hermes/backups/broken_state 2>/dev/null | wc -l` and `journalctl --user -u <watchdog> | grep -c "Restored:"` — hundreds of snapshots proves the disaster path looped and rewrote config repeatedly, so later config drift is a symptom of the loop, not a separate bug.
6. Config drift, without leaking secrets: `diff <(sed -E 's/(key|token|secret)[^:]*:.*/\1: REDACTED/I' cfg) <(same on known-good copy)`; `sha256sum .env known-good/.env` (digests only; never `cat` an env file, never print a key).

## Rules

- **Cadence arithmetic identifies the culprit.** Watchdog interval × MAX_FAILS gives the destruction period (5 min × 3 ≈ 15–18 min observed). If the observed restart period matches, the watchdog is the cause.
- **Probes must read the identifier from the config the service actually reads** — model id, endpoint, port, unit name. A hardcoded id rots the moment a provider renames or retires it, and then every tick manufactures a fake outage.
- **Restore/rollback automation must trigger only on transport failures.** A 4xx-class error is a config/auth problem that restoring config cannot fix; restoring a weeks-old "known-good" re-imposes retired ids and rotated keys and self-perpetuates the loop.
- **A rollback is fault injection unless it is refreshed.** Snapshot the current files into `broken_state/` immediately before overwriting, and refresh the known-good copy on every healthy run.
- **Freeze before fixing.** `systemctl --user stop <watchdog>.timer` is the smallest reversible action; it stops imminent damage while you patch. Nothing is deleted.
- **Do not blame the loop for what you have not checked.** Before reporting "the restore wiped secret X", prove it existed: `grep -c '^X=' current.env known-good/.env broken_state/.env.*`. Zero hits in every snapshot means it was never provisioned.

## Verification after the fix

- `bash -n <script>` before enabling.
- `systemctl --user show <watchdog>.service -p Result -p ExecMainStatus --value` → `success` / `0`.
- Fail-counter file absent (a lingering counter means the healthy path was never exercised).
- `systemctl --user show <target> -p ActiveEnterTimestamp --value` unchanged — proof the good run did not restart anything.
- Re-enable the timer and confirm the next tick is silent.

## Harness caveat

The terminal tool refuses to execute a script that can restart the gateway from inside the gateway process (SIGTERM would kill the test mid-run). Test only the probe logic — copy it into a scratch script with no restart branch and run that; then exercise the real unit in its own scope with `systemctl --user start <unit>.service`.
