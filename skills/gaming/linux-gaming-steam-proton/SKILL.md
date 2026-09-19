---
name: linux-gaming-steam-proton
description: Use when setting up/optimizing Steam/Proton games on Linux.
version: 1.0.0
author: hermes-curator
license: CC-BY-4.0
platforms: [linux]
metadata:
  hermes:
    tags: [gaming, steam, proton, linux, nvidia, optimization, wine]
    category: gaming
---

# Linux gaming via Steam/Proton

## When to use
Any Steam game setup, optimization, or troubleshooting on this box: installing a game, choosing a Proton build, launch options, download monitoring, first-run launcher issues, hybrid-GPU display questions, or "what settings for <game>".

Games come and go and the user pivots mid-task (RDR2 → Far Cry 6 in one sitting). Keep the pipeline **parametric**: game name, Steam appid, launch options, settings recipe are inputs, never hardcoded. Do not invest in game-specific finalization (cheat sheets, config) until the user commits to that title.

## Environment (this machine)
- Hybrid GPU: internal eDP-1 = Intel iGPU (i915); external HDMI = NVIDIA dGPU-direct (no mux, no PRIME copy tax). The external HDMI is the gaming path. The panel runs on the iGPU, so disabling it (`kscreen-doctor output eDP-1 disable` — NOT lid close, which may suspend) buys thermals/cleanliness, ~0-3 FPS: not a real lever. Confirm topology with `kscreen-doctor -o` / `/sys/class/drm/card*-*/status`.
- NVIDIA driver mismatch (loaded != installed) needs the USER to reboot; verify after with `/proc/driver/nvidia/version` vs `pacman -Q nvidia-open nvidia-utils`, then `nvidia-smi`.
- Steam config: `~/.steam/root/userdata/<steam3id>/config/localconfig.vdf` (see `references/localconfig-vdf-patching.md`).

## Procedure
1. **Prereqs**: multilib enabled, disk free, pacman DB current (no needless `-Syu`). Install via pkexec `--noconfirm`.
2. **Driver sync**: compare loaded vs installed driver; mismatched → reboot (user's step), then verify.
3. **Tooling (once)**: `gamemode lib32-gamemode mangohud lib32-mangohud gamescope`.
4. **GE-Proton (once)**: download tarball + `.sha512` from GloriousEggroll/proton-ge-custom releases → `sha512sum -c` → extract into `~/.steam/root/compatibilitytools.d/` → rename dir to `GE-Proton11-7` (no hyphen-suffix noise) → verify `version` file + `proton` binary + `compatibilitytool.vdf`. Steam auto-detects at next start. GE-Proton is the go-to for cutscene-heavy games (bundles the codecs stock Proton lacks).
5. **Game install**: drive via Steam GUI; monitor with `references/steam-download-monitoring.md` (ACF counters lie).
6. **Config**: set compat tool + launch options with `scripts/steam_config_patcher.py` — Steam fully closed; dry-run first; backup+atomic+round-trip verify. Launch options on this laptop: `gamemoderun prime-run %command%` (prepend `MANGOHUD=1` only while tuning; add NVAPI/DLSS env only for DLSS-capable titles).
7. **First run**: expect the publisher-launcher login dance (Ubisoft Connect etc.) inside the Proton sandbox; one game restart fixes most stalls. Verify forced tool via game Properties → Compatibility.
8. **Tune**: research ProtonDB + real GPU benchmarks BEFORE quoting numbers — user wants quantified expectations, not vibes; laptop Max-Q ≈ 10-25% under desktop equivalents. VRAM-limited recipe (4GB): 1080p-class rendering (or native res + FSR), ray tracing OFF, textures High not Ultra, skip vendor HD texture packs (they want >6GB VRAM), other settings Medium. Tune live with MangoHud.
9. **Report**: quantified table (expected FPS per settings tier), honest provenance of the numbers, biggest lever first (resolution/FSR — not panel-off).

## Pitfalls
- **Steam's appmanifest `BytesDownloaded` is lazily flushed** — it can sit flat 20+ min during a full-speed download. Gauge real progress by `downloading/` dir growth or `/proc/<pid>/io` (see reference). Never declare "stalled" from the ACF counter alone.
- **Steam rewrites `localconfig.vdf` from memory while running** — any external edit is clobbered. Patch only when no steam/steamwebhelper/steam-runtime processes exist (tray icon counts as running).
- **`pgrep -f` self-matches your own wrapper cmdline** — the searched text lives in the shell's own command line, so `pgrep -f 'steam'` matches the terminal wrapper running your command. Probe process NAMES with `ps -eo comm= | grep -xE 'steam|steamwebhelper|...'`, never full-cmdline for self-probing.
- **Hand-rolled VDF parse: top level is key→value** — consume the key string, THEN the value (a bare `parse_value` returns the first key as a scalar). Serialize quoted keys/values, braces, tab indent, escaped `\\`/`\"`; verify by re-parsing the written file.
- **The bar hitting 100% is not the end** — Steam then stages/verifies (CPU-bound: sha1 verify + zstd decompress across ~8 cores; fans pinned, 80°C is fine, not a fault). Done = StateFlags 4 + `BytesDownloaded==BytesToDownload` + `downloading/` empty. Quiet option: Settings → Downloads → bandwidth limit.
- **User left mid-install?** Set a no_agent cron watchdog (hermes-cron-operations) rather than holding the chat open; completion chain: wait staging → quit Steam → patch → verify → report.
- **Installs are loud by design**: diagnose fans in one shot (`uptime`, top CPU `ps`, thermal zones, fan RPM) and map them to the pipeline before calling anything wrong.

## Support files
- `references/steam-download-monitoring.md` — real progress gauges, ACF field decoding, staging pass, fan-noise diagnosis.
- `references/localconfig-vdf-patching.md` — VDF structure, safe patch workflow, rollback.
- `scripts/steam_config_patcher.py` — validated patcher: dry-run, backup, atomic swap, round-trip verify.
