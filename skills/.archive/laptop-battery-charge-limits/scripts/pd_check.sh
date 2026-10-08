#!/bin/bash
# Dump the REAL power path on a USB-C PD laptop: negotiated vs capable wattage.
# Diagnoses "AC shows online but battery drains while plugged in".
# Mains AC entry often reports only online (no current numbers) -> look at ucsi ports.
echo "=== all power supplies ==="
ls /sys/class/power_supply/

echo
echo "=== AC (Mains) attrs ==="
for f in online type voltage_now current_now power_now; do
  printf "  %-12s %s\n" "$f" "$(cat /sys/class/power_supply/AC/$f 2>/dev/null || echo MISSING)"
done

echo
echo "=== USB-C PD ports (the real charger path) ==="
for p in /sys/class/power_supply/ucsi-source-psy-*; do
  [ -e "$p" ] || continue
  echo "-- $p"
  for f in online type voltage_now current_now power_now voltage_max current_max; do
    printf "  %-12s %s\n" "$f" "$(cat $p/$f 2>/dev/null || echo MISSING)"
  done
  on=$(cat $p/online 2>/dev/null)
  v=$(cat $p/voltage_now 2>/dev/null); vm=$(cat $p/voltage_max 2>/dev/null)
  c=$(cat $p/current_now 2>/dev/null); cm=$(cat $p/current_max 2>/dev/null)
  if [ "$on" = "1" ] && [ -n "$vm" ] && [ -n "$v" ] && [ "$v" -lt "$vm" ]; then
    echo "  >>> NEGOTIATED BELOW CAPABLE: ${v}uV vs max ${vm}uV — PD fallback (bad cable/brick) suspected"
  fi
done

echo
echo "=== kernel PD/charger chatter (recent) ==="
dmesg 2>/dev/null | grep -iE "ucsi|typec|pd_|charger|usbpd" | tail -25