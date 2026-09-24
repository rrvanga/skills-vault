---
name: media-card-ingestion
description: Use when copying media off a mounted camera or USB card.
---

# Media card ingestion (camera / USB)

Safely move media (video/photo) off a mounted memory card to the computer, verify byte-for-byte, clear the card, and eject. Golden rule: **never delete from the card until a clean verification pass proves the copy is exact.** Worst case of an interrupted copy = files still on the card, retry possible; worst case of premature deletion = permanent data loss.

User preferences that govern this class of task:
- Plan first, narrate each step as you go (plain-language teaching), verify before claiming done.
- "Careful with the data" means checksum-level integrity and a gated deletion — never rm before a zero-diff verification pass.
- Notify completion on the user's home channel (e.g. `hermes send --to telegram`) if requested.

## Workflow

1. **Locate the device (read-only).**
   `lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS,TRAN,MODEL`
   Narrow with findmnt, filtering pseudo-filesystems:
   `findmnt -rn -o TARGET,SOURCE,FSTYPE,LABEL | grep -iv 'loop|tmpfs|proc|sys|cgroup|devpts|mqueue|shm|overlay|efivarfs|bpf|tracefs|debugfs|securityfs|pstore|hugetlbfs|configfs|fusectl'`
   Cameras usually show as exFAT, user-mounted under `/run/media/<user>/<LABEL>`.

2. **Inventory the card — count and SIZE case-insensitively.**
   Camera extensions are typically UPPERCASE (`.MP4`, `.JPG`, `.LRF`). A lowercase-only `find` undercounts sizes silently:
   `find /run/media/<user>/<LABEL> -type f -iname '*.MP4' | wc -l` and sum bytes per type via `-printf '%s\n' | awk '{s+=$1} END{print s/1e9 " GB"}'`.
   Record total count + total size; every later check compares against these.

3. **Check existing organization conventions** (see `~/Videos`, `~/Pictures`, `~/Documents`) before choosing the destination. Prefer a dated folder matching where prior media of that type lives, e.g. `~/Videos/OsmoAction_2026-08-21/`.

4. **Copy with checksum verification baked in (background):**
   `mkdir -p <dest> && rsync -a --checksum --info=stats1 <src>/ <dest>/`
   Run with `background=true, notify_on_complete=true`; the completion notification resumes the follow-up sequence automatically.

5. **Expect the false-alarm "stall"** — do NOT panic at an empty destination early on. With `--checksum`, rsync hashes the file list up front and destination grows only after each file's hash completes (for large media, minutes). Health-check instead:
   - `ps -o stat,etime -p <rsyncPID>` → `D` state = disk I/O wait (healthy)
   - `ls -l /proc/<PID>/fd | grep -oE 'DJI_[^/]+'` → file advancing = working
   - `/proc/<PID>/io` read_bytes vs write_bytes → `--checksum` shows a DOUBLE-read signature (total reads ≈ 2× card size: one pass to hash, one to send). Write_bytes climbing means files are landing.
   - Live progress summary: `scripts/rsync_progress.sh <PID> <dest>` (see support scripts).

6. **Verify before any deletion — second checksum pass, zero-diff:**
   `rsync -a --checksum --dry-run -i <src>/ <dest>/` → output must be EMPTY (anything listed = difference). Also confirm file count and total size match step 2. Only a clean pass opens the deletion gate.

7. **Clear the card — narrow scope.** Delete only the media directories' *contents* (`DCIM/*`, `MISC/*` — thumbnails/.db are regrown by the camera). **Leave `LOST+FOUND` untouched** (filesystem artifact, not media). Then `sync` to flush.

8. **Confirm the wipe** (destination untouched, card shows ~0 used), then unmount + eject — user-owned mounts need no sudo:
   `udisksctl unmount -b /dev/X && udisksctl power-off -b /dev/X`
   Verify the mount is gone (`findmnt` / `lsblk` shows no mountpoint). `power-off` leaves the card in safe-to-remove state.

9. **Report and notify.** Final summary = src/dest paths, file counts + sizes, verification result, disk free after. If the user asked for a completion ping on Telegram/etc, use `hermes send --to telegram "<summary>"` (home chat; confirm target via `hermes status`).

## Pitfalls

- **Case-sensitive extension counting** silently corrupts size math on camera cards — always `-iname`.
- **`--checksum` empty-destination false stall** — verify via `/proc/<pid>/io` + fd before assuming a hang. Never kill a healthy copy to "restart it".
- **Deleting before verification** — the one irreversible mistake in this workflow; the zero-diff pass is mandatory, not optional.
- **`rm -rf` on the whole mount root** could remove `LOST+FOUND` and system dirs the camera needs; scope deletion to `DCIM/* MISC/*` contents.
- **Unmount without `sync`** risks a dirty card; flush first. Mount may be managed by the desktop session — `udisksctl` respects the user-owned mount, no sudo needed. If the card is busy (any process holds an fd), unmount fails cleanly — find and close the holder rather than forcing.

## Support files

- `scripts/rsync_progress.sh` — live progress probe for a running rsync PID + destination (size, count, current file, throughput delta).
- `references/dji-osmo-action-2026-08.md` — worked example: real numbers, timings, and the `--checksum` read signature from an 18 GB card copy.