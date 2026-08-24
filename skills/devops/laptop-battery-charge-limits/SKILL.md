---
name: laptop-battery-charge-limits
description: Use when setting/verifying laptop battery charge limits.
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [laptop, battery, charge-limit, sysfs, tmpfiles, logind, longevity]
    related_skills: [linux-system-audit, hermes-session-forensics]
---

# Laptop battery charge limits

Keep a laptop battery healthy when it's parked on AC 24/7 (home-server / NAS duty). A battery held at 100% forever wears fast (high voltage = calendar aging); the fix is a charge cap band plus lid-close behavior that doesn't kill the server.

## When to Use

- Laptop repurposed as an always-on home server → set a longevity band + lid-close handling
- User asks to "change battery settings", "limit charging", or reports the battery is always at 100%
- Verifying whether a previously staged battery script was actually applied

## The sysfs ABI (Linux, kernel ↔ embedded controller)

`/sys/class/power_supply/BAT0/` (model-specific path; enumerate `ls /sys/class/power_supply/`):
- `charge_control_end_threshold` — stop charging at N% (default 100)
- `charge_control_start_threshold` — resume charging below N% (default 0)
- `status` — Charging / Discharging / Full;  `capacity` — current %
- `energy_full` / `energy_full_design` → health ≈ energy_full ÷ design (e.g. 73.7/80.4 Wh ≈ 92%); `cycle_count`

If these files exist, the EC supports native caps — **no daemon (TLP) needed**: two sysfs writes suffice.

## Procedure

1. **Recon first, write nothing**: read current thresholds + status + health, check lid default (`HandleLidSwitch` in logind). State the plan before touching anything.
2. **Choose the band**: 40–60% = maximum-lifespan / storage profile (server/UPS duty); 60–80% = reasonable daily too. Standard traveller's band almost never chosen.
3. **Apply** (needs root):
   ```bash
   printf '40' | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold > /dev/null
   printf '60' | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold   > /dev/null
   ```
4. **Persist across boots** via `systemd-tmpfiles.d` (no daemon):
   ```ini
   # /etc/tmpfiles.d/battery-thresholds.conf
   w /sys/class/power_supply/BAT0/charge_control_start_threshold - - - - 40
   w /sys/class/power_supply/BAT0/charge_control_end_threshold   - - - - 60
   ```
   `sudo systemd-tmpfiles --create /etc/tmpfiles.d/battery-thresholds.conf`
5. **Lid-close for server duty** — `/etc/systemd/logind.conf.d/server-laptop.conf`:
   ```ini
   HandleLidSwitchExternalPower=ignore
   ```
   then `sudo systemctl daemon-reload && sudo systemctl restart systemd-logind`.
6. **Verify**: read back the two thresholds, confirm the tmpfiles and logind.d files exist, optionally `grep HandleLidSwitch /etc/systemd/logind.conf.d/*.conf`.

## Two-person sudo rule (this user)

Passwordless sudo is NOT enabled and the agent never handles passwords. When root is required:
- Stage the full script (e.g. `/tmp/battery_server.sh`), show the user what it does, and hand them one command: `bash /tmp/battery_server.sh` (one sudo prompt, ~5s).
- Ask them to paste the output back; then verify end-to-end.
- **Before claiming "pending" vs "done", check ground truth**: `grep -c battery_server ~/.bash_history` (0 = never run), read the live sysfs thresholds, `ls /etc/tmpfiles.d /etc/systemd/logind.conf.d`.

## Pitfalls

- TLP config dialect (`START_CHARGE_THRESH_BAT0` / `STOP_CHARGE_THRESH_BAT0`) maps 1:1 to start/end sysfs values — same intent, but TLP itself is unnecessary when sysfs caps exist.
- `echo 100 | sudo tee .../charge_control_end_threshold` = one-shot "fill it for the trip" override; it lasts until next boot (tmpfiles re-applies the band).
- Write values via `printf '40' | sudo tee` — bare `echo` can add a newline that some ECs reject; `set -e` scripts must guard against that.
- A staged script in `/tmp` dies on reboot (`/tmp` is volatile) — if the user reboots before running it, re-stage.