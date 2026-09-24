# Worked example: DJI Osmo Action card copy (2026-08-21)

Real run that established this workflow. Card: DJI Osmo Action, exFAT 48G, label `OsmoAction`,
user-mounted at `/run/media/<user>/OsmoAction/` (device `/dev/sda`).

## Card inventory (case-insensitive — extensions are UPPERCASE)

- 451 files, ~18 GB total: 54 MP4 (13.41 GB), 78 JPG (0.11 GB), plus sidecars
  `.LRF` (low-res video preview), `.THM`/`.SCR` (thumbnails), `.db` (media index).
- Layout: `DCIM/DJI_001/`, `MISC/`, `LOST+FOUND/`.
- Pitfall caught live: first tally lowercased extensions and the size math was wrong;
  re-ran with `find -iname` and got the real numbers.

## Copy command

```
rsync -a --checksum --info=stats1 /run/media/<user>/OsmoAction/ \
      /home/<user>/Videos/OsmoAction_2026-08-21/
```
Background with notify_on_complete (session proc_7a2e04603868, rsync child PID 342374).

## Timings / --checksum behavior observed

- First 5 min: destination stuck at 16 K / 0 files while read_bytes climbed — the
  front-loaded hashing phase (each whole file read + hashed BEFORE it is written).
- At 10:43 elapsed: 5.6 GB / 50 files written, ~19 MB/s effective to destination.
- /proc/<pid>/io showed ~11 GB read at 5 min vs 0 written — the double-read signature
  (1x hash pass + 1x send pass) makes total reads ~= 2x card size.
- Health confirmed via: rsync child in `D` state (disk I/O wait), fd listing showed
  the current source file advancing between checks (DJI_20260720... -> DJI_20260722...).

## Verification + clearing plan (the deletion gate)

1. Second pass: `rsync -a --checksum --dry-run -i src/ dest/` must output NOTHING.
2. Confirm count (451) and total size match inventory.
3. Only then: delete `DCIM/*` and `MISC/*` contents; keep `LOST+FOUND`; `sync`.
4. `udisksctl unmount -b /dev/sda && udisksctl power-off -b /dev/sda` (no sudo,
   user-owned mount); verify gone via lsblk/findmnt.
5. Notify: `hermes send --to telegram "<summary>"` (home chat id confirmed via
   `hermes status`: "Telegram ✓ configured (home: <REDACTED>)").

## Lesson

An "empty destination" early in a --checksum copy is expected, not a stall.
Measure via /proc (io + fd), never kill-and-restart a healthy copy.