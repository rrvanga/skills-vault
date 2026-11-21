# Patching Steam localconfig.vdf (compat tool + launch options)

Target: `~/.steam/root/userdata/<steam3id>/config/localconfig.vdf` — per-account config, NOT cloud-synced. `<steam3id>` = the numeric dir under `userdata/` (`ls ~/.steam/root/userdata/`).

## Blocks to insert (inside UserLocalConfigStore → Software → Valve → Steam)
- **LaunchOptions** → `apps → <appid>`:
  `"LaunchOptions" "gamemoderun prime-run %command%"`
- **CompatToolMapping** → `<appid>`:
  ```
  "name"     "GE-Proton11-7"
  "config"   ""
  "priority" "250"
  ```
  (priority 250 = manual force; 0 = default tool)

## Safety workflow (Steam MUST be fully closed)
Steam rewrites this file from its in-memory state on exit — any edit while it runs gets clobbered. Tray icon counts as running.
1. Verify no processes: `ps -eo comm= | grep -xE 'steam|steamwebhelper|steam-runtime-launcher-service'` — empty required. Never `pgrep -f` (self-matches your own wrapper cmdline).
2. Backup: copy to `localconfig.vdf.bak-<epoch>`.
3. Dry-run first: `python3 scripts/steam_config_patcher.py --dry-run --appid <id> --launch '<opts>'`.
4. Apply: the script parses the whole file (fail = no write), rewrites atomically (temp file + os.replace), then re-parses the result to verify the round trip.
5. Evidence: grep the inserted keys out of the written file and show the user.
6. Rollback: restore the `.bak`, or rerun with the original values.

GUI fallback (zero-risk, user at keyboard): game Properties → Compatibility → force tool + paste launch options. Use it whenever the user is available.

## VDF parsing notes (if you must hand-roll)
- Top level is key→value exactly like a dict entry: parse the key string, THEN the value. A bare `parse_value` on the file returns the first *key* as a scalar.
- Strings escape `\\` and `\"`. Serialize quoted keys/values, braces, tab indent (Steam's own format); re-parse after write and compare.
