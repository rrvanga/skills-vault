---
name: linux-audio-troubleshooting
description: Use when audio is quiet, capped, or missing on Linux.
version: 1.0.0
author: hermes (<REDACTED>)
license: MIT
metadata:
  hermes:
    tags: [audio, pipewire, wireplumber, plasma, arch, troubleshooting]
    related_skills: [bluetooth-audio-repair, linux-system-audit]
---

# Linux Audio Troubleshooting (PipeWire / KDE Plasma)

## When to use
Built-in speakers or laptop audio is quiet, missing, or stops at 100% despite everything looking maxed. Covers the gain chain (sink → per-app stream → codec) and KDE Plasma volume-button caps. For a BT headset that never shows a sink, use `bluetooth-audio-repair` instead.

## Diagnosis ladder — find where the gain is lost (do in order)
1. **Sink level**: `wpctl get-volume @DEFAULT_AUDIO_SINK@`; `pactl list sinks` → Mute/Volume/active port (`analog-output-speaker` vs headphones).
2. **Per-app stream**: `pactl list sink-inputs` → check each app stream's volume. A quiet APP stream is the usual cause of "speakers are quiet" — per-app volumes persist across restarts via module-stream-restore, so a stale app-mixer setting (e.g. 64% = −11.6 dB) survives reboots and reads as a hardware fault. Check this layer BEFORE touching hardware.
3. **Hardware codec**: `/proc/asound/card*/codec#*` — Speaker Amp-Out `vals [0x4a 0x4a]` with caps `ofs=0x4a nsteps=0x4a` = max gain; pin-ctls `0x40` OUT with EAPD set = enabled; `[0x80 0x80]` = muted amp. If sink AND codec are both maxed, attenuation is in the app/stream layer, period.

## Raising volume above 100%
- `wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.5` (or `2.0`, tested) — PipeWire accepts >1.0 raw without preamp config.
- Past 0.00 dB the extra gain is a PipeWire SOFTWARE preamp (the codec amp is already at max). Clipping risk rises with hot sources; back off to ~1.5 if it sounds harsh. Revert: `wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0`.
- Sink-input IDs are ephemeral: if `pactl set-sink-input-volume <id>` fails "No such entity", the stream cycled — re-enumerate `pactl list short sink-inputs` and loop the set over the live ids.

## KDE Plasma: volume keys stop at 100%
- The widget setting is "Raise maximum volume": config key `raiseMaximumVolume=true` in `~/.config/plasma-org.kde.plasma.desktop-appletsrc` under the volume applet's `[Configuration][General]` group (`[Containments][…][Applets][…][Applets][<id>][Configuration][General]`).
- Find the applet id: grep the file for `plugin=org.kde.plasma.volume`; the section immediately after is its config group (it already holds `migrated=true`).
- This toggle's ceiling is a FIXED 150% — for a custom cap (e.g. 200%) you need WirePlumber config, not the toggle.
- Authoritative keys for compiled applets: Plasma 6.7 ships the volume applet as a compiled C++ plugin (`/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.volume.so`) with no QML/config on disk, and `strings` on the .so hides the config keys. Fetch the schema upstream instead: GitLab API tree `https://invent.kde.org/api/v4/projects/plasma%2Fplasma-pa/repository/tree?path=applet&ref=Plasma/6.7` → raw `applet/main.xml` lists every config key + default.
- Back up appletsrc before editing; the applet reads its config at load.

## Restarting plasmashell from a headless agent session
- Stop: `kquitapp6 plasmashell` — it maps to the `plasma-plasmashell.service` user unit; kwin/startplasma-wayland does NOT auto-respawn the shell.
- Start: `systemctl --user start plasma-plasmashell.service` — the ONLY reliable relaunch. Agent terminal sessions have no DISPLAY/WAYLAND_DISPLAY, so direct `plasmashell`/`kstart*` invocations fail silently or land on the wrong session.
- Health-check after restart: `systemctl --user is-active plasma-plasmashell.service` + `pgrep -a plasmashell`.
- The terminal tool rejects `&`-backgrounding inside a foreground command — relaunch via systemd or `background=true`, never a trailing `&`.
- Plasma config is a plain INI in `~/.config/` — edit with the patch tool, back up first; reversibility is a copy-delete.

## Verification (read-back, not vibes)
- `wpctl get-volume @DEFAULT_AUDIO_SINK@` after ANY change.
- `pactl list sinks` / `pactl list sink-inputs` → mute off, sane volumes, streams on the intended sink.
- `systemctl --user is-active plasma-plasmashell.service` after a shell restart; confirm the panel/tray recovered.

## Environment notes (this box)
- Built-in sink: `alsa_output.pci-0000_00_1f.3.analog-stereo` (Conexant CX11880 codec, `front:0`).
- amixer/alsamixer are not installed and not needed — wpctl/pactl/pw-cli cover the whole workflow.
- Firefox runs as Flatpak; its stream-restore id is `sink-input-by-application-name:Firefox`.
