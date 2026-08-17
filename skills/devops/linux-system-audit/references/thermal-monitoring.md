# Thermal monitoring (Linux host watchdog)

Continuous temp watching on this box (ThinkPad i7-9750H / GTX 1650 Max-Q / NVMe).
Pairs with the no_agent cron contract in hermes-cron-operations: script is silent
unless a threshold is crossed, so a healthy run burns zero tokens and delivers nothing.

## Sensor source inventory (where the temps live)

| Source | Path / command | Units |
|---|---|---|
| Kernel zones | `/sys/class/thermal/thermal_zone*/` — glob, each zone has `type` + `temp` | temp is **millidegrees** (÷1000) |
| CPU | zone type `x86_pkg_temp` (Intel) / `k10temp` (AMD) | same |
| Wi-Fi | iwlwifi exposes a zone too (laptops) — match on zone TYPE string, not path | same |
| NVIDIA GPU | `nvidia-smi --query-gpu=name,temperature.gpu --format=csv,noheader` | °C already |
| NVMe | `/sys/class/nvme/nvme0/hwmon*/temp1_input` — glob `hwmon*` under the nvme class dir; no smartctl needed | millidegrees |
| Fans/EC | `sensors` (lm-sensors; thinkpad-isa on ThinkPads) | RPM |

## Watchdog script design (deployed: `~/.hermes/scripts/thermal_watch.py`)

- Silent by default: print NOTHING when every sensor is below thresholds (empty
  stdout = no cron delivery; non-zero exit = error alert if ALL sources fail).
- Per-sensor `(warn, crit)` tuples; print one formatted alert listing all temps
  when any crosses. Threshold defaults on this box: CPU 85/95, GPU 85/95,
  NVMe 65/75, Wi-Fi 90/95.
- Test hook: `THERMAL_TEST=1` env var forces the alert branch — no heating needed.
- Cron: `no_agent=true`, `script=thermal_watch.py` (real copy in `~/.hermes/scripts/`),
  `every 5m`, deliver to origin.

## Pitfalls (learned the hard way)

- **Forced-alert test must assert EVERY sensor appears in the output** — not just
  that an alert fires. Wi-Fi sat at 49°C and was silently missing from the alert
  while the zone existed; a simple pass/fail "did it alert" check never caught it.
- **Dict-unpacking variable swap**: `for z, zt in zones.items(): if "iwlwifi" in zt`
  binds `zt` to the VALUE (the path `thermal_zone18`), so the substring match
  silently never fires — and `zones[zt]` would KeyError if it ever did. Unpack as
  `for ztype, zpath in zones.items():` and match on the TYPE. When a source is
  mysteriously absent, replicate the exact iteration logic in isolation and dump
  the bindings (zone type → path map) before assuming the sensor is missing.
- **Millidegrees**: sysfs `temp` files are °C × 1000. Forgetting the ÷1000 turns a
  53°C idle into 53000 and false-alarms the whole board.

## Verification sequence

1. Normal run: exit 0, EMPTY output (silence = healthy).
2. `THERMAL_TEST=1` run: alert prints and lists ALL monitored sensors.
3. Fire through the scheduler once (`cronjob action='run'`): `status: ok` +
   silent outcome proves cron plumbing can find and execute the script.
