#!/usr/bin/env bash
# Canonical installer for the battery band watchdog (root).
# Two-person sudo: agent stages, user runs `sudo bash <this file>` (ONE password prompt).
# Order is load-bearing: ENABLE the timer FIRST (safety net live) BEFORE applying the
# band live, so any EC latch from applying above-end is cured within 2 minutes.
# Verify afterwards: timer enabled/active, thresholds 25/60, watchdog log line.
# Rollback: sudo systemctl disable --now battery-band-watchdog.timer && rm the 3 files.

set -u
BAT="${BAT:-/sys/class/power_supply/BAT0}"
START="${START:-25}"
END="${END:-60}"
SRC_DIR="${SRC_DIR:-/tmp}"          # where staged watchdog/service/timer live
RESULT="${RESULT_LOG:-/tmp/battery_watchdog_install_result.txt}"

exec > >(tee "$RESULT") 2>&1        # capture everything for the agent to verify

echo "== battery-band watchdog installer =="
date

set -e
echo "[1/6] install watchdog script"
install -m 0755 "$SRC_DIR/battery-band-watchdog.sh" /usr/local/sbin/battery-band-watchdog.sh

echo "[2/6] install systemd units"
install -m 0644 "$SRC_DIR/battery-band-watchdog.service" /etc/systemd/system/battery-band-watchdog.service
install -m 0644 "$SRC_DIR/battery-band-watchdog.timer"    /etc/systemd/system/battery-band-watchdog.timer

echo "[3/6] tmpfiles boot band -> ${START}/${END}"
install -m 0644 "$SRC_DIR/tmpfiles-battery-thresholds.conf" /etc/tmpfiles.d/battery-thresholds.conf

echo "[4/6] daemon-reload + enable/start timer (safety net live BEFORE band apply)"
systemctl daemon-reload
systemctl enable --now battery-band-watchdog.timer

echo "[5/6] apply live band ${START}/${END}"
printf '%s' "$END"   > "$BAT/charge_control_end_threshold"
printf '%s' "$START" > "$BAT/charge_control_start_threshold"
sleep 3

echo "[6/6] smoke test: run the watchdog once"
systemctl start battery-band-watchdog.service

echo "== RESULT =="
echo "timer: $(systemctl is-enabled battery-band-watchdog.timer) / $(systemctl is-active battery-band-watchdog.timer)"
echo "band:  start=$(cat "$BAT/charge_control_start_threshold") end=$(cat "$BAT/charge_control_end_threshold")"
echo "batt:  status=$(cat "$BAT/status") capacity=$(cat "$BAT/capacity")%"
echo "watchdog event: $(cat /home/<REDACTED>/.hermes/cache/battery-band-watchdog/last_event 2>/dev/null || echo none)"
echo "tmpfiles: $(grep -c charge_control /etc/tmpfiles.d/battery-thresholds.conf) threshold lines at next boot"
echo "DONE"
echo
echo "Press Enter to close this window..."
read -r _