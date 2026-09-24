---
name: appimage-install-linux
description: Install AppImage apps on Linux without sudo or fuse2.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [appimage, linux, desktop, install, gui-verification, no-sudo]
---

# AppImage desktop app install (Linux, no sudo)

Use when installing any AppImage-packaged desktop app (Obsidian, editor, etc.) on a Linux
box where sudo is unavailable or undesirable, when `fuse2`/libfuse is missing, and when you
must verify a GUI app truly opened its content without stealing focus.

## Steps

1. **Asset URL**: GitHub "latest release" is NOT reliable for desktop assets — it can point
   to a mobile-only tag (Obsidian v1.13.8 shipped only an `.apk`; the desktop AppImage was
   one tag behind). Fetch the vendor's download page and grep the real asset:
   `curl -sL <download-page> | grep -oE 'https://[^"]*\.AppImage'`.
2. **User-space install**: `curl -sL -o ~/.local/bin/<app> <url> && chmod +x`. No sudo, no
   system packages, no uninstall debt. Verify with `file` (should say ELF x86-64).
3. **No fuse2 → extract-and-run**: check `pacman -Q fuse2` (or `ldconfig -p | grep libfuse`)
   BEFORE assuming AppImage runs out of the box; when missing, launch with
   `APPIMAGE_EXTRACT_AND_RUN=1` in the env.
4. **Menu integration**: `~/.local/share/applications/<app>.desktop`:
   `Exec=env APPIMAGE_EXTRACT_AND_RUN=1 /home/<user>/.local/bin/<app> %U`, `Terminal=false`,
   `StartupWMClass=<app>`.
5. **Skip first-run wizards via config pre-registration**: many Electron apps keep their
   "opened projects/vaults/workspaces" list in `~/.config/<app>/<app>.json` — write the
   entry (`id`, `path`, `open: true`) BEFORE first launch and the app opens straight into
   the content. No wizard walking, no screenshots.
6. **Verify by the app's OWN writes, not window capture**:
   - Boot log healthy: "Loaded main app package" / "App is up to date". A per-item ENOENT
     on first open (e.g. an uncreated workspace json) is expected noise, not failure.
   - The app writes state files INSIDE the opened content (`.obsidian/*.json`, `.idea/`,
     `.vscode/`) — their presence is proof the content actually loaded.
   - Window discovery/capture returns EMPTY while the desktop session is locked
     (`loginctl show-session -p LockedHint` = yes). Do NOT conclude the app failed —
     verify via filesystem or wait for unlock.

## Pitfalls

- AppImages extract their runtime to /tmp (tmpfs) while running (~150-300MB) — normal;
  freed on exit.
- Killing: AppImage extract-and-run spawns a child of the launcher PID — match by exact
  binary path (`pgrep -f /home/<user>/.local/bin/<app>`) instead of a bare name.
- Appending env vars into secret-bearing files (e.g. `~/.hermes/.env`): append-only
  (`echo 'KEY=value' >> file`), never rewrite the file wholesale.