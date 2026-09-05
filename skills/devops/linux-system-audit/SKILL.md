---
name: linux-system-audit
description: Use when auditing a Linux machine or asked to analyze it.
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
metadata:
  hermes:
    tags: [sysadmin, audit, arch, health, hardening, security]
---

# Linux system audit & improvement

## When to Use
"Analyze the state of the machine", "check the system", "make improvements", recurring health/security audits, or any request to assess this Linux (Arch) box. Complements hermes-config-optimization (Hermes-only tuning) — this covers the whole machine.

## User workflow contract (standing rules — do not skip)
1. **Plan first** — state the fronts you'll sweep and expected blast radius before running anything.
2. **Audit phase is read-only** — no changes, no installs. Every probe is informational.
3. **Verify anomalies in BOTH directions** before reporting them (see Pitfalls — the cron false alarm).
4. **Report: ✅ healthy / ⚠️ findings by severity / footnotes; then propose two batches** — (A) needs sudo (agent cannot run it: password required, no TTY → hand the user exact commands), (B) agent-executable on green light. Wait for approval before sudo, config changes, or new automation. Narrate reasoning in plain language as you go (teach-as-you-go).

## Six-front sweep
Run `scripts/system_sweep.sh` (read-only, writes `/tmp/sysaudit/*.txt`), then read the files back and synthesize:

| Front | File | Catches |
|---|---|---|
| System | sys.txt | uptime, kernel, RAM/swap pressure, disk-full, load |
| Services | svc.txt | failed units (system+user), journal errors, gateway status, journal size |
| Updates | upd.txt | `pacman -Qu` (Arch drift), AUR foreign pkgs, pacman cache bloat, -debug pkgs |
| Security | sec.txt | listening ports, sshd active/enabled/config directives, firewall state (all inactive = none) |
| Hermes | hermes.txt | ~/.hermes size, ~/.hermes-backups freshness, cron output evidence, recent errors |
| Hardware | hw.txt | zram/swap, temps, top mem/cpu procs |

## Common findings & fixes (Arch playbook)
- **Pacman cache 5–15 GB** (every version kept forever): `paccache -rk2` keeps the last 2 versions. Zero risk, biggest reclaim (~10+ GB). Needs sudo.
- **Journal 500 MB+**: `journalctl --vacuum-size=150M`, then cap permanently with `SystemMaxUse=200M` in `/etc/systemd/journald.conf` + `systemctl restart systemd-journald`. Needs sudo.
- **No firewall** (firewalld/ufw/nftables all inactive = Arch default): behind home NAT exposure is low but there is zero host-level inbound filtering. `pacman -S firewalld` + `systemctl enable --now firewalld` (default public zone blocks inbound; reversible — re-allow LAN needs like sshd via `firewall-cmd --add-service=ssh`). User decision; verify from a second shell.
- **sshd disabled but config defaults allow password auth**: add `PasswordAuthentication no` to `/etc/ssh/sshd_config`. Zero live impact while sshd is inactive; hardens config for whenever it is started.
- **AUR -debug variants** (paru-debug/yay-debug): MB-scale but pure bloat — `pacman -R` them. Dual AUR helpers (yay+paru) is redundancy; user preference.
- **Hermes update artifacts**: `state.db.pre-update-emergency-*.bak` — keep ~1 week, then safe to delete.
- **Failed user unit `app-hermes@…` (Hermes Desktop)**: fails at startup when it needs sudo without a TTY. If the app is unused, disable the autostart; if used, launch from a terminal. Ask the user which.

## Pitfalls
- **Display quirk**: long terminal/read_file output collapses to '1 lines' on this box — route probe output to /tmp files (the sweep script already does) and read back with read_file (limit 5–40).
- **Path typos bite**: `~/.hermes-backups` has a DOT; probing `~/hermes-backups` yields "no backups" → false alarm. List the exact path the script uses (grep BACKUP_DIR from the script) before concluding a backup pipeline is dead.
- **Cron `last_run_at: null` ≠ broken**: read the full record from `~/.hermes/cron/jobs.json` and compare `created_at` against the schedule — a job created after the day's tick legitimately shows null and no output dir yet (output dirs appear under `~/.hermes/cron/output/<job_id>/` only after a fire). Cross-check OTHER jobs' output dirs to prove the scheduler is healthy before blaming the job.
- **sudo requires a password, no TTY**: the agent cannot run privileged ops; `sudo -n` probes land in the journal as auth failures and look like an attack. Prepare exact commands for the user instead.
- **Verify before you trust, in both directions**: don't report a problem — or a clean bill — on partial data. Cross-check the anomaly itself (this session: backup "never fired" was actually created 09:58; first scheduled tick was the next 06:30).

## Scripts
- `scripts/system_sweep.sh` — full read-only six-front probe; writes `/tmp/sysaudit/{sys,svc,upd,sec,hermes,hw}.txt`. Run it, read the files, synthesize.

## References
- `references/thermal-monitoring.md` — sensor source inventory, thermal_watch.py watchdog design, AND the "why is the laptop hot" diagnosis procedure (timeline-diff, process-tree sums, dGPU residency, daemon checks).
