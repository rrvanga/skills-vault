#!/bin/bash
# Measure REAL battery charge/discharge rate by sampling energy_now twice.
# status alone lies ("Not charging" can mean draining); energy delta is the truth.
# Usage: bash charge_probe.sh [seconds]   (default 60s)
# Positive rate = charging, negative = draining (mW).
B=/sys/class/power_supply/BAT0
S=${1:-60}
e1=$(cat $B/energy_now); t1=$(date +%s)
sleep "$S"
e2=$(cat $B/energy_now); t2=$(date +%s)
d=$(( (e2 - e1) * 3600 / (1000 * (t2 - t1)) ))
echo "window: ${t1} -> ${t2} ($((t2-t1))s)"
echo "energy_now: $e1 -> $e2 (Δ=$((e2-e1)) µWh)"
echo "capacity=$(cat $B/capacity) status=$(cat $B/status)"
echo "charge rate ≈ $d mW"