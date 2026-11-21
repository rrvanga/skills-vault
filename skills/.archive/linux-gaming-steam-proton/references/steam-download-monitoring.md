# Steam download monitoring (real progress vs the lying counter)

Steam per-app manifest `~/.steam/root/steamapps/appmanifest_<appid>.acf` download fields are **lazily flushed snapshots** — `BytesDownloaded` can sit flat for 20+ minutes while the download runs at full speed. Never conclude "stalled" from ACF alone.

## Real-progress gauges
- Depot disk growth (best):
  ```
  a=$(du -sb ~/.steam/root/steamapps/downloading/ | cut -f1); sleep 15; b=$(du -sb ~/.steam/root/steamapps/downloading/ | cut -f1)
  echo "$(( (b-a)/1024/1024 )) MiB in 15s"
  ```
  Rate → ETA = remaining / sampled rate.
- Process throughput: `write_bytes` and `wchar` from `/proc/<steam pid>/io`. Grep the exact `^write_bytes:` line — a bare `/write_bytes/` regex also matches `cancelled_write_bytes`.
- Sanity: apparent zero on a >30MB/s pipe = flush lag; widen the window before declaring anything.

## ACF field decoding
- `StateFlags 4` = fully installed; anything else (e.g. 1026) = download/update in progress.
- Complete = `BytesDownloaded == BytesToDownload`, `BytesStaged == BytesToStage`, `SizeOnDisk > 0`, and `downloading/` empty.
- `SizeOnDisk` is ~1.1-1.3× the downloaded size (dedup/staging) — 119GB on disk for a 94GB download is normal.
- Prerequisite depots (Proton Experimental, Steamworks redist, runtime, e.g. appids 1493710/228980/4183110) download before the game's own manifest appears; the store API returns "(no data)" for these internal appids — resolve names via `https://store.steampowered.com/api/appdetails?appids=<id>` and treat no-data as internal.

## The post-download staging pass
Steam keeps ~6-8 CPU cores busy (sha1 verify + zstd decompress) AFTER the bar hits 100%: fans stay pinned, package temps ~80°C are fine. Finish = fan drops and `StateFlags` flips to 4.
Quiet option: Settings → Downloads → bandwidth limit (less data → less CPU → quieter, slower), or suspend.

## Fan-noise diagnosis (one shot)
`uptime` (load), `ps -eo pcpu,comm --sort=-pcpu | head`, `/sys/class/thermal/thermal_zone*/temp`, `/sys/class/hwmon/*/fan1_input`. Install pipeline maxed = normal; nothing is broken. Cool down 2-3 min before launching the game so the chassis sheds heat.
