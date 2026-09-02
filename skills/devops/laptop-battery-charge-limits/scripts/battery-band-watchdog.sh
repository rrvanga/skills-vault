#!/usr/bin/env bash
# battery-band-watchdog.sh — ROOT systemd-timer watchdog for the ThinkPad EC charge latch.
#
# Theory: the EC latches "Not charging" when a charge band (start/end thresholds) is
# applied while capacity >= end. Replug does NOT clear it; reboot does NOT clear it
# (the gauge re-learns energy_full, % jumps, no energy flows). The ONLY proven cure is
# rewriting the thresholds: relax to 0/100, wait ~1s, re-apply the band.
#
# This watchdog detects the latched state and replays that exact cure, hands-free.
# Ticks every 2 min via battery-band-watchdog.timer (see SKILL.md). Writes an event
# file that the user-level Telegram monitor reads (e.g. ~/.hermes/scripts/battery-band-monitor.sh).
#
# Install (two-person sudo rule): stage this file + the .service/.timer units, user
# runs the one-shot sudo installer; rollback = disable timer + delete script.

BAT=/sys/class/power_supply/BAT0
AC=/sys/class/power_supply/AC
EVENT_DIR="${EVENT_DIR:-/var/lib/battery-band-watchdog}"
EVENT_FILE="$EVENT_DIR/last_event"
STATE_FILE="$EVENT_DIR/state"     # "last_action_ts write_count"
LOG_FILE="$EVENT_DIR/log"

QUIET_S="${QUIET_S:-900}"         # 15 min quiet window after any action (write-storm guard)
EXP_START="${EXP_START:-25}"      # band floor  — tune to the CURRENT energy_full gauge
EXP_END="${EXP_END:-60}"          # band ceiling — NEVER write a band while cap >= end

mkdir -p "$EVENT_DIR"

read_int() {
  local f=$1 v
  [[ -r "$f" ]] || { echo -1; return; }
  v=$(cat "$f" 2>/dev/null | tr -d '[:space:]')
  case "$v" in ''|*[!0-9]*) echo -1 ;; *) echo "$v" ;; esac
}

start=$(read_int "$BAT/charge_control_start_threshold")
end=$(read_int "$BAT/charge_control_end_threshold")
status=$(cat "$BAT/status" 2>/dev/null | tr -d '[:space:]')
cap=$(read_int "$BAT/capacity")
ac=$(read_int "$AC/online")
now=$(date +%s)

# No band configured / sysfs unreadable → nothing to do.
if [[ "$start" == "-1" || "$end" == "-1" || ( "$start" == "0" && "$end" == "0" ) ]]; then
  exit 0
fi

# Normal states — never act here:
#  - AC absent            → on battery, intended.
#  - Charging / Full      → healthy; reset the throttle counter.
#  - cap >= end (here >= EXP_END is equivalent) → "Not charging" is CORRECT.
if [[ "$ac" != "1" || "$status" == "Charging" || "$status" == "Full" || "$cap" -ge "$EXP_END" ]]; then
  [[ "$status" == "Charging" || "$status" == "Full" ]] && echo "0 0" > "$STATE_FILE"
  exit 0
fi

last_ts=0; writes=0
[[ -f "$STATE_FILE" ]] && read -r last_ts writes < "$STATE_FILE" 2>/dev/null

log() { echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"; }

# ── Latch branch: AC online + cap below the floor + not charging ─────────────
if [[ "$cap" -lt "$EXP_START" ]]; then
  if [[ "$last_ts" -gt 0 ]] && (( now - last_ts < QUIET_S )); then
    exit 0                                   # quiet window — don't write-storm sysfs
  fi
  # Proven un-latch sequence (keeps the band semantics: relax, let EC re-evaluate, re-apply):
  echo 100    > "$BAT/charge_control_end_threshold"
  echo 0      > "$BAT/charge_control_start_threshold"
  sleep 1
  echo "$EXP_END"   > "$BAT/charge_control_end_threshold"
  echo "$EXP_START" > "$BAT/charge_control_start_threshold"
  echo "$now $((writes + 1))" > "$STATE_FILE"
  log "RECOVERED cap=${cap}% status=${status} thresholds ${start}/${end} -> ${EXP_START}/${EXP_END}"
  echo "RECOVERED $(date '+%F %T') cap=${cap}% status=${status} start=${start}->${EXP_START} end=${end}->${EXP_END}" > "$EVENT_FILE"
  exit 0
fi

# ── Band-drift branch: thresholds changed by PowerDevil/tmpfiles/user, cap below end ──
if [[ "$start" != "$EXP_START" || "$end" != "$EXP_END" ]]; then
  echo "$EXP_END"   > "$BAT/charge_control_end_threshold"
  echo "$EXP_START" > "$BAT/charge_control_start_threshold"
  echo "$now $((writes + 1))" > "$STATE_FILE"
  log "BAND_RESTORED start=${start}->${EXP_START} end=${end}->${EXP_END} cap=${cap}%"
  echo "BAND_RESTORED $(date '+%F %T') cap=${cap}% start=${start}->${EXP_START} end=${end}->${EXP_END}" > "$EVENT_FILE"
fi

exit 0