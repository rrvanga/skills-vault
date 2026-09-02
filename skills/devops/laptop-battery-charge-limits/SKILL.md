---
name: laptop-battery-charge-limits
description: Use when diagnosing or tuning laptop charge thresholds (ThinkPad EC latch, sysfs BAT0, charge bands). Verified battery measurement, latch cure, root watchdog.
---

# Laptop Battery Charge Limits & EC Latch

ThinkPad (and some Dell/Lenovo) laptops expose charge-band thresholds via sysfs: limit the
charging window to e.g. 25–60% to slow wear, and the embedded controller (EC) decides when
to charge. This skill covers reading the REAL state, the EC latch failure mode, and an
auto-recovery watchdog that makes the latch self-healing.

## Ground truth — trust sysfs, never firmware/UI

- `/sys/class/power_supply/BAT0/` — the source of truth:
  - `status` (`Charging` / `Not charging` / `Full` / `Discharging`) — **lies**; see below.
  - `capacity` — **percent is arithmetic** (`energy_now / energy_full`); see the re-learn trap.
  - `energy_now`, `energy_full` (µWh) — the only numbers you believe for "is it charging".
  - `charge_control_start_threshold` / `charge_control_end_threshold` — the band.
- `/sys/class/power_supply/AC/online` — mains adapter present (barrel chargers report ONLY
  `online`, no voltage/current numbers; that is normal, not a failure).
- `upower` can report stale thresholds and stale percentages — **do not trust it**, re-read sysfs.
- Charging truth = signed `energy_now` delta: read twice N seconds apart; rate ≈
  ΔµWh × 3600 ÷ s ÷ 1000 → mW. Positive = charging, negative = draining.
  Run `scripts/charge_probe.sh` instead of hand-typing.

## PITFALL: capacity% jumps do NOT prove charging

After a reboot / suspend the gauge can **re-learn `energy_full`** (measured: 118.2 → 70.6 Wh
in one reboot). Same stored energy ÷ smaller full value = higher %. A "35% → 59%" jump can
be pure arithmetic while `energy_now` actually FELL. **Never declare "the reboot fixed it"
from capacity%. Always confirm with an `energy_now` delta.** The taskbar icon re-uses the
same arithmetic — it lies alongside.

## PITFALL: `ucsi-source-psy-*` = the port POWERING a device, not the charger

On USB-C laptops, `ucsi-source-psy-USBC000:0xx` entries show a port in **source** role —
the laptop delivering 5V to an attached phone/dongle. A reading like `5V × 3A = 15W` there
is NOT the charger negotiating poorly; it is the laptop feeding some sink device. Only
`ucsi-sink-psy-*`/the relevant port in sink role reflects an incoming USB-C charger, and
only on USB-C-PD-charged machines. On barrel/SlimTip ThinkPads the real input is the Mains
`AC` entry (online only). Do not diagnose "weak charger" from source-role ports.

## The ThinkPad EC latch (session-proven, 2026-09-02)

**Symptom:** AC online, `status=Not charging`, capacity *below* the band floor. The EC has
latched "stop charging".

**Cause:** the band was written while the battery was near/above the end threshold (e.g.
applying 40/60 while the pack was at ~100%). The EC latched and will not re-evaluate.

**What does NOT clear it (tested, measured):**
- AC replug — 45s sample showed 0 mW; latch held.
- Reboot — resets the EC but the gauge re-learn distort makes it LOOK fixed (see trap
  above); no energy flows.

**The proven cure: rewrite the thresholds.** Relax the band, let the EC re-evaluate, then
re-apply:

```bash
echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold
echo 0   > /sys/class/power_supply/BAT0/charge_control_start_threshold
sleep 1
echo 60 > /sys/class/power_supply/BAT0/charge_control_end_threshold      # your band
echo 25 > /sys/class/power_supply/BAT0/charge_control_start_threshold
```

Result within seconds: `status=Charging`, measured 35.4W into the battery on a 65W brick.
Sysfs writes print nothing on success — an "empty result" from sudo IS the success.

## Auto-recovery watchdog (root systemd timer)

The latch ends hands-free with a 2-minute root systemd timer running
`scripts/battery-band-watchdog.sh` (installed to `/usr/local/sbin/`). Logic per tick:

- AC off → normal battery use, no-op. Charging/Full → healthy, reset throttle, no-op.
- `AC=1 && cap < start && status != Charging` → LATCHED → write `0/100`, sleep 1, write the
  band (exactly the proven manual cure), log, write an event file.
- Band drifted (`≠` expected) → restore it **only while `cap < end`**. Writing a band while
  capacity ≥ end is the ORIGINAL latch cause — never do it.
- 15-min quiet window after any action (no write storms); event file is read by the
  user-level Telegram monitor so the user gets "⚡ watchdog recovered charging" alerts.

Install via the two-person sudo rule below (staged script, user runs ONE sudo command).
Rollback: `sudo systemctl disable --now battery-band-watchdog.timer` + delete the script.

## Charging complaint triage (fast path)

1. `cat /sys/class/power_supply/BAT0/{status,capacity,energy_now,energy_full,charge_control_start_threshold,charge_control_end_threshold}`
2. Measure a real energy delta (`scripts/charge_probe.sh`). Flat/negative while "plugged in" = real problem.
3. Check the latch condition (AC=1, cap<start, Not charging) → rewrite thresholds (cure above).
4. Charger health: only suspect the brick/cable on USB-C-PD machines via sink-role ports +
   `dmesg | grep -iE 'ucsi|typec|charger'`. On barrel machines the AC entry has no numbers;
   a healthy 65W brick charging at ~35W input with the system idle is NORMAL (35 battery +
   ~30 system ≈ 65W brick rating).
5. Band tuning: pick the band on the **current** `energy_full` gauge — a % band means
   different Wh reserve after a re-learn. User's machine settled on 25/60 after the gauge
   re-learned to 70.6 Wh (≈17–42 Wh reserve). Never apply a band while the pack is at/near
   100% — that is the latch recipe.

## Two-person sudo rule (no passwordless sudo)

Threshold files are root-owned; the agent must NOT handle passwords. Stage every command
and script under `/tmp`, hand the user exactly ONE sudo command, then read back and verify
the sysfs values yourself. Scripts over raw one-liners — raw commands confuse ("What does
this even mean").

## Pitfalls

- `status` coexists with slow charging AND with draining — never trust it alone.
- Capacity% jumps on gauge re-learn — verify with `energy_now` deltas.
- AC replug and reboot do NOT clear the EC latch — threshold rewrite does.
- `ucsi-source-psy` = source-role port, not the charger input.
- Writing thresholds while cap ≥ end re-creates the latch.
- `upower` reports stale data — trust sysfs.
- Applied band changes live in sysfs are immediate and root-owned — plan the blast radius.

## Support files

- `scripts/charge_probe.sh` — energy_now delta probe (charging truth).
- `scripts/pd_check.sh` — charger/port path dump for USB-C PD machines.
- `scripts/battery-band-watchdog.sh` — root watchdog: EC-latch auto-recovery + band enforce.
- `references/charge-diagnostics-and-ec-latch.md` — full 2026-09-02 session detail:
  measured numbers, the false-victory trap, corrected ucsi reading, watchdog design.