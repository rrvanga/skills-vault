# Cron delivery pitfalls (desktop-session jobs)

## The `deliver: 'local'` default trap

Creating a cron job from a **desktop/CLI session** (no live-delivery channel)
silently resolves `deliver` to `'local'`: the job runs, records output to
`~/.hermes/cron/output/<job_id>/`, but the alert reaches NOBODY. A watchdog that
was supposed to page the user just archives itself. Discovered 2026-08-15 when a
Go-bucket watchdog was created from the desktop app and only 'local' delivery was
wired until corrected.

**Rule**: for any user-facing watchdog/report created from a desktop session:
1. `cronjob list` → read sibling gateway-created jobs' `deliver` value (they
   almost always use `'origin'`, which resolves to the gateway-connected channel,
   e.g. Telegram DM).
2. Create the job, then `cronjob action=update deliver='origin'` if it landed as
   'local'.
3. Re-list and confirm `deliver` is not 'local' before declaring done.

Caveat: in a desktop session `'origin'` may be unresolvable at creation time
(that's WHY the default is 'local') — the update after creation is the fix, and
the gateway resolves 'origin' at fire time.

## Related known guard

The `script` field takes only a bare filename relative to `~/.hermes/scripts/`
(absolute paths and escaping symlinks rejected) — see the SKILL.md Pitfalls
section for the full guard and the real-file-copy deployment pattern.
