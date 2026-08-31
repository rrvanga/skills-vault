---
name: bluetooth-audio-repair
description: Use when BT headset is connected but has no audio sink.
version: 1.0.0
author: hermes (<REDACTED>)
license: MIT
metadata:
  hermes:
    tags: [audio, bluetooth, pipewire, wireplumber, arch, troubleshooting]
    related_skills: [linux-system-audit, hermes-agent]
---

# Bluetooth Audio Repair (PipeWire/WirePlumber)

## When to use
Bluetooth headset/earbuds pair and link (`bluetoothctl` shows `Connected: yes`) but never appear as an audio sink in `wpctl status` / `pactl list sinks`. Often happens after a user-session rebuild or DE change. Linux/Arch/PipeWire context.

## Triage order (inspect everything before touching anything)
1. Identify the REAL connected device — never trust the assumed one:
   `bluetoothctl devices Connected` → then `bluetoothctl info <MAC> | grep Connected`
2. Confirm the gap is below BlueZ:
   - `pactl list modules short | grep bluez` — empty means PipeWire's bluez5 never loaded
   - `pw-cli load-module module-bluez5` → `Could not load module` = config gap, not codec gap
3. Inspect WirePlumber session config (usual root cause):
   `ls /usr/share/wireplumber/wireplumber.conf.d/` — if it holds ONLY minimal hand-rolled files (e.g. `alsa-vm.conf`), Bluetooth has no component to load. Also check `~/.config/wireplumber/wireplumber.conf.d/`.
4. Sanity (usually fine, check once): `pipewire-audio` owns `/usr/lib/spa-0.2/bluez5/libspa-bluez5.so`; BlueZ service active; `pipewire.conf` declares bluez5. **There is NO `wireplumber-audio` package in Arch repos** (`error: package 'wireplumber-audio' was not found`) — don't chase it. `bluetooth.conf` ships only as a doc example under `/usr/share/doc/wireplumber/examples/`.

## Fix (user-level drop-in, NO root)
```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp /usr/share/doc/wireplumber/examples/wireplumber.conf.d/bluetooth.conf \
   ~/.config/wireplumber/wireplumber.conf.d/50-bluez-config.conf
systemctl --user restart wireplumber pipewire pipewire-pulse
bluetoothctl disconnect <MAC> && sleep 2 && bluetoothctl connect <MAC>
```
Persists across reboots; reversible by deleting the drop-in. VENDOR EXAMPLE PATH MUST EXIST — verify with `ls` before the cp.

## Route & unmute (use pactl NAMES, not wpctl-friendly-name greps)
```bash
pactl set-default-sink bluez_output.XX_XX_XX_XX_XX_XX.1
pactl set-sink-mute   bluez_output.XX_XX_XX_XX_XX_XX.1 0
pactl set-sink-volume bluez_output.XX_XX_XX_XX_XX_XX.1 70%
```
Move already-playing app audio (e.g. a meeting app that grabbed the old default) onto the BT sink:
```bash
BT_ID=$(pactl list short sinks | awk '/bluez_output/{print $1}')
pactl list short sink-inputs | while read idx cur rest; do
  [ -n "$idx" ] && [ -n "$cur" ] && [ "$cur" != "$BT_ID" ] && pactl move-sink-input "$idx" "$BT_ID"
done
```

## Pitfalls
- `wpctl status` lists friendly names (e.g. `EarFun Air Pro 4`), NOT `bluez_output.*` ids → greps for ids fail silently. Use pactl by exact node name.
- `org.bluez.Error.InProgress br-connection-busy` = a daemon-level connect already in flight — poll/wait, never stack connects.
- The connected pair may NOT be the pair you assume — `bluetoothctl devices Connected` settles identity.
- User in a meeting: NEVER blast test tones. Verify via graph state + sink-input routing instead.
- Diagnostics discipline: write `/tmp/diag*.sh` → run with output redirected to file → `wc -l` → `read_file` BEFORE claiming anything. One-line truncated echoes lie.
- Session rebuilds can replace/minimize the WirePlumber config dir — if BT audio "just stopped working" after a session restart, re-check step 3.

## Verification (read-back, not vibes)
- `wpctl status` → `*` on `bluez_output.<MAC>.1`, no MUTED
- `pactl list sinks` → State: RUNNING (if audio streaming), Mute: no, sane volume
- `pactl list sink-inputs` → app inputs point at the BT sink id
- `systemctl --user is-active wireplumber pipewire pipewire-pulse` → active ×3

## Environment notes (this box, verified 2026-08-29)
- Already fixed; drop-in installed at `~/.config/wireplumber/wireplumber.conf.d/50-bluez-config.conf`.
- Pairs: EarFun Air Pro 4 `70:5A:6F:6B:5D:A1` (active A2DP sink `bluez_output.70_5A_6F_6B_5D_A1.1`), CMF Headphone Pro `2C:BE:EE:3C:4F:CE` (paired, dormant). Built-in speaker sink: `Built-in Audio Analog Stereo`.
- Stack: PipeWire 1.6.8, WirePlumber, Arch.