#!/usr/bin/env bash
# system_sweep.sh — read-only six-front health probe for a Linux (Arch) box.
# Writes sectioned output to /tmp/sysaudit/<front>.txt. Makes NO changes.
# Usage: bash system_sweep.sh   then read /tmp/sysaudit/*.txt
set -u
OUT=/tmp/sysaudit
mkdir -p "$OUT"

{
  echo "=== UPTIME/KERNEL ==="; uptime; uname -r
  echo "=== MEM ==="; free -h
  echo "=== LOAD ==="; cat /proc/loadavg
  echo "=== DISK ==="; df -hT -x tmpfs -x devtmpfs
} > "$OUT/sys.txt" 2>&1

{
  echo "=== FAILED UNITS (system) ==="; systemctl --failed --no-legend 2>&1
  echo "=== FAILED UNITS (user) ==="; systemctl --user --failed --no-legend 2>&1
  echo "=== JOURNAL ERRORS this boot ==="; journalctl -p 3 -b --no-pager 2>/dev/null | tail -20
  echo "=== GATEWAY ==="; systemctl --user status hermes-gateway --no-pager 2>&1 | head -8
  echo "=== JOURNAL SIZE ==="; du -sh /var/log/journal 2>/dev/null
} > "$OUT/svc.txt" 2>&1

{
  echo "=== PACMAN PENDING UPDATES ==="; pacman -Qu 2>&1 | head -40
  echo "=== FOREIGN (AUR) PKGS ==="; pacman -Qm 2>/dev/null | head -15
  echo "=== PACMAN CACHE ==="; du -sh /var/cache/pacman/pkg 2>/dev/null
  echo "=== CACHE PKG COUNT ==="; ls /var/cache/pacman/pkg 2>/dev/null | wc -l
  echo "=== DEBUG PKGS ==="; pacman -Qi paru-debug yay-debug 2>/dev/null | grep -E "^(Name|Installed Size)"
  du -sh /usr/lib/debug 2>/dev/null
} > "$OUT/upd.txt" 2>&1

{
  echo "=== LISTENING PORTS (non-loopback) ==="; ss -tulpn 2>/dev/null | grep -v "127.0.0.1\|::1" | head -15
  echo "=== SSHD ACTIVE/ENABLED ==="; systemctl is-active sshd 2>&1; systemctl is-enabled sshd 2>&1
  echo "=== SSHD CONFIG DIRECTIVES ==="
  grep -E "^\s*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config 2>/dev/null \
    || echo "(no explicit directives — package defaults apply; Arch default allows password auth)"
  echo "=== FIREWALL (active services) ==="
  for s in firewalld ufw nftables iptables; do printf "%s: " "$s"; systemctl is-active "$s" 2>/dev/null || echo inactive; done
} > "$OUT/sec.txt" 2>&1

{
  echo "=== HERMES SIZE ==="; du -sh ~/.hermes 2>/dev/null
  echo "=== HERMES TOP DIRS ==="; du -sh ~/.hermes/* 2>/dev/null | sort -rh | head -8
  echo "=== BACKUPS (note the DOT in .hermes-backups) ==="; ls -lat ~/.hermes-backups 2>/dev/null | head -8 || echo "no ~/.hermes-backups"
  echo "=== CRON OUTPUT EVIDENCE (dir per job that has fired) ==="; ls -lat ~/.hermes/cron/output/ 2>/dev/null | head -10
  echo "=== RECENT ERRORS ==="; tail -8 ~/.hermes/logs/errors.log 2>/dev/null
} > "$OUT/hermes.txt" 2>&1

{
  echo "=== ZRAM/SWAP ==="; zramctl 2>/dev/null; swapon --show 2>/dev/null
  echo "=== TEMPS ==="; sensors 2>/dev/null | grep -E "Core|Package|temp1" | head -10
  echo "=== TOP MEM PROCS ==="; ps aux --sort=-%mem | head -8
  echo "=== TOP CPU PROCS ==="; ps aux --sort=-%cpu | head -8
} > "$OUT/hw.txt" 2>&1

wc -l "$OUT"/*.txt
