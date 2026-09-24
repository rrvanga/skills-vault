#!/usr/bin/env bash
# Live progress probe for a running rsync copy.
# Usage: rsync_progress.sh <rsync_child_PID> [destination_dir]
# Reports: process state/elapsed, destination size + file count,
#          current source file (from /proc/PID/fd), read/write deltas
#          over a 5s sample (throughput).
set -u
PID="${1:?usage: rsync_progress.sh <PID> [dest]}"
DEST="${2:-}"

echo "== rsync PID $PID =="
ps -o stat=,etime= -p "$PID" 2>/dev/null | sed 's/^/state: /' || { echo "PID gone -- finished or died."; exit 1; }

echo "== current source file =="
ls -l "/proc/$PID/fd" 2>/dev/null | grep -oE '(DCIM|MISC)/[^ ]+' | head -1 || echo "(none open)"

if [ -n "$DEST" ]; then
  echo "== destination =="
  du -sh "$DEST" 2>/dev/null | awk '{print "size: " $1}'
  find "$DEST" -type f 2>/dev/null | wc -l | sed 's/^/files: /'
fi

echo "== throughput (5s sample) =="
R1=$(awk '/read_bytes/{print $2}' "/proc/$PID/io" 2>/dev/null)
W1=$(awk '/write_bytes/{print $2}' "/proc/$PID/io" 2>/dev/null)
sleep 5
R2=$(awk '/read_bytes/{print $2}' "/proc/$PID/io" 2>/dev/null)
W2=$(awk '/write_bytes/{print $2}' "/proc/$PID/io" 2>/dev/null)
awk -v r1="$R1" -v r2="$R2" -v w1="$W1" -v w2="$W2" 'BEGIN{
  printf "read:  %.2f MB/s | total read:  %.2f GB\n", (r2-r1)/5/1e6, r2/1e9;
  printf "write: %.2f MB/s | total written: %.2f GB\n", (w2-w1)/5/1e6, w2/1e9;
  printf "note: with --checksum, total read ~= 2x card size (hash pass + send pass)\n"}'