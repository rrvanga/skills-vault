#!/usr/bin/env bash
# battery-band-watchdog.sh — ROOT watchdog for the ThinkPad EC charge latch.
# Un-sticks the EC when it refuses to charge below the band floor, and
# re-applies the 25/60 longevity band when it is safe to do so.
# Runs every 2 min from a systemd timer. All actions logged; user monitor
# (battery-band-monitor.sh, Telegram) reads last_event.
#
# TESTABLE: BAT, AC, OWNER_DIR are env-overridable — point them at a fake
# sysfs tree to simulate branches (see SKILL.md; suite: 8/8 PASS).

BAT=${BAT:-/sys/class/power_supply/BAT0}
AC=${AC:-/sys/class/power_supply/AC/online}

# Desired longevity band (must match /etc/tmpfiles.d/battery-thresholds.conf)
START=25
END=60

# Emergency quiet window after an action (seconds)
BACKOFF=900

# Where root writes state + events; chowned to the user so the monitor can read
OWNER_DIR=${OWNER_DIR:-/home/<REDACTED>/.hermes/cache/battery-band-watchdog}
STATE="$OWNER_DIR/state"
EVENT="$OWNER_DIR/last_event"
LOG="$OWNER_DIR/log"
mkdir -p "$OWNER_DIR"
chown <REDACTED>:<REDACTED> "$OWNER_DIR" 2>/dev/null || true

now=$(date +%s)
read_val() { cat "$1" 2>/dev/null | tr -d '\n'; }

cap=$(read_val "$BAT/capacity");   ac=$(read_val "$AC")
start=$(read_val "$BAT/charge_control_start_threshold")
end=$(read_val "$BAT/charge_control_end_threshold")
status=$(read_val "$BAT/status")

[ -n "$cap" ] && [ -n "$ac" ] || exit 0   # battery or AC disappeared — nothing to do

log() {
  local line="$(date '+%F %T') $*"
  echo "$line" >> "$LOG"; chown <REDACTED>:<REDACTED> "$LOG" 2>/dev/null || true
  echo "$line" > "$EVENT"; chown <REDACTED>:<REDACTED> "$EVENT" 2>/dev/null || true
}

last_act=$(sed -n 's/^LA=//p' "$STATE" 2>/dev/null); last_act=${last_act:-0}
should_backoff() { [ $(( now - last_act )) -lt "$BACKOFF" ]; }

# On pure battery: charging is impossible, this is normal — never touch.
[ "$ac" = "1" ] || exit 0

# Ceiling insurance: band armed (25/60) yet EC still charging at/above end.
# Re-assert the stop. SKIPPED when band is disarmed (0/100) by the user —
# that is a deliberate calibration fill, hands off.
if [ "$start" = "$START" ] && [ "$end" = "$END" ] && \
   [ "$status" = "Charging" ] && [ "$cap" -ge "$END" ] 2>/dev/null; then
  printf '%s' "$END"   > "$BAT/charge_control_end_threshold"
  printf '%s' "$START" > "$BAT/charge_control_start_threshold"
  log "ENFORCED_END: charging at ${cap}% >= ${END} with band armed — re-asserted ${START}/${END}"
  echo "LA=$now" > "$STATE"; chown <REDACTED>:<REDACTED> "$STATE" 2>/dev/null || true
  exit 0
fi

# Charging: all healthy; reset the backoff clock so we can act immediately
# if the EC stops charging again.
if [ "$status" = "Charging" ]; then
  echo "LA=0" > "$STATE"; chown <REDACTED>:<REDACTED> "$STATE" 2>/dev/null || true
  exit 0
fi

# recover(): the proven un-latch. Write 0/100 (full re-evaluation — exactly
# what the manual sudo did this morning), wait, then re-apply the band.
recover() {
  local why="$1"
  printf '100' > "$BAT/charge_control_end_threshold"
  printf '0'   > "$BAT/charge_control_start_threshold"
  sleep 1
  printf '%s' "$START" > "$BAT/charge_control_start_threshold"
  printf '%s' "$END"   > "$BAT/charge_control_end_threshold"
  log "RECOVERED: $why (cap=${cap}% status=${status} ac=${ac})"
}

if should_backoff; then exit 0; fi

# 1) The latch: below the floor but not charging, with AC present.
if [ "$cap" -lt "$START" ] 2>/dev/null && [ "$status" != "Charging" ]; then
  recover "EC latch: cap ${cap}% < start ${START}% but status=${status}"
  echo "LA=$now" > "$STATE"; chown <REDACTED>:<REDACTED> "$STATE" 2>/dev/null || true
  exit 0
fi

# 2) Band drift: restore 25/60 ONLY when below the end threshold.
#    Above end it would re-create the latch (band applied while full).
if { [ "$start" != "$START" ] || [ "$end" != "$END" ]; } && [ "$cap" -lt "$END" ] 2>/dev/null; then
  recover "band drift start=${start} end=${end} (restored ${START}/${END}; cap=${cap}% < end)"
  echo "LA=$now" > "$STATE"; chown <REDACTED>:<REDACTED> "$STATE" 2>/dev/null || true
  exit 0
fi

exit 0