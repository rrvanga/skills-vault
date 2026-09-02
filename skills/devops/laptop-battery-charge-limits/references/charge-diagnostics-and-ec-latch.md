# Charge diagnostics & EC latch — measured session detail (2026-09-02, ThinkPad X1 Extreme Gen2)

Full evidence behind the SKILL.md rules. Machine: X1E2 (20QV), 135W design, 65W barrel
(SlimTip) adapter, battery gauge re-learned 118.21 → 70.64 Wh at reboot (≈21% of design
remaining; cycle count ~32.8k as reported). All numbers measured, not assumed.

## Idle-vs-load draw truth
- Genuine idle (load avg 0.06): 6 × 10s windows, battery perfectly flat — **0 mW**.
- A −380,000 µWh/60s ≈ 22.8W "drain" reading was taken UNDER load (diagnostics + gateway),
  not idle. Always record load context with draw numbers.

## The latch, step by step (with tests)
1. Aug 31 boot: 40/60 band applied while battery ≈ 100% → EC latched "stop charging".
2. Symptom: AC online, cap 35% (below floor), `Not charging`, 0 mW.
3. **AC replug test (user unplugged/replugged): FAILED.** 45s sample = 0 mW, still
   `Not charging`. Threshold file was re-written by an unknown service at the AC event
   (PowerDevil `chargethresholdhelper` suspected) and still refused.
4. **Reboot test: NOT a fix.** Capacity jumped 35% → 59% and looked fixed, but:
   `energy_now` fell 42,040,000 → 41,570,000 µWh (boot drew ~0.5 Wh) and `energy_full`
   collapsed 118,210,000 → 70,640,000 µWh. 41.57/70.64 = 58.8% — pure arithmetic. Zero
   charge. Also: post-rebaseline 59% sits INSIDE 40/60 → `Not charging` was now CORRECT
   band behavior, not a latch. The goalposts moved.
5. **Threshold rewrite (user ran the sudo command): THE cure.** `echo 100 > end; echo 0 >
   start` → `status=Charging` within seconds. Measured **35.4W** into battery over 60s
   (44.32 → 44.91 Wh; 59% → 64% → 65%, climbing at the 35W rate). Taskbar icon then agreed.

Learned: replug and reboot are NOT reliable un-latch procedures; threshold rewrite is.

## The ucsi-source-psy misread (retracted theory)
- Earlier theory: "charger stuck at 5V/3A = 15W < 65W → PD handshake failed".
- Correction: `ucsi-source-psy-USBC000:00{1,2}` = the port acting as power SOURCE to an
  attached sink (phone/dongle). The barrel adapter is the real input (AC/Mains, online=1,
  no numeric fields on barrel machines). The 65W brick was healthy all along: 35.4W into
  battery + ~30W system ≈ 65W brick rating.

## Watchdog design (approved by user; built and staged)
- Root systemd timer, every 2 min (OnBootSec=2min, OnUnitActiveSec=2min; oneshot service
  After=multi-user.target). Root needed: threshold files are root-owned.
- Detection: `AC=1 && cap < start && status != Charging` → EC latched.
- Recovery: write `0/100`, sleep 1, write band (25/60) — exactly the manual cure.
- Band drift (≠25/60): restore ONLY while `cap < 60` — never write a band above the end
  threshold (that is the original latch cause).
- Throttle: 15-min quiet window after any action; charging resets the backoff.
- Telemetry: append to log + write `last_event` file that the user-level Telegram monitor
  (`~/.hermes/scripts/battery-band-monitor.sh`, 6h cron) reads → "⚡ watchdog recovered
  charging at …" alert. Monitor state resets each boot.
- Band rationale: 25/60 on the re-learned 70.6 Wh gauge ≈ 17–42 Wh reserve. A % band is
  gauge-relative — re-tune after any `energy_full` re-learn.
- Install: one-shot sudo installer staging script to `/usr/local/sbin/`, registering
  service+timer, `systemctl enable --now battery-band-watchdog.timer`.
  Rollback: `sudo systemctl disable --now battery-band-watchdog.timer` + delete the file.

## Sysfs quirks observed
- Silent writes: threshold writes print nothing; "empty result" from sudo = success (verify
  by re-reading the files).
- `capacity` = `energy_now / energy_full` — never trust after reboot without checking both.
- `upower` stale: can report old thresholds/lifetimes; trust sysfs directly.