# DRM / display / GPU diagnostics (Linux, Arch)

## When to use
External display stuck at 640x480 (or a mode list that makes no sense), monitor "not detected" / wrong resolution, nvidia-smi or CUDA apps failing with driver/library mismatch, GPU-role questions ("which GPU drives what").

## This box's topology (Lenovo 229f / X1E Gen 2)
- PCI 00:02.0 Intel UHD 630 (i915) = card1; owns eDP-1 (internal panel) ONLY.
- PCI 01:00.0 NVIDIA GTX 1650 Mobile Max-Q (open module) = card0; owns DP-1, DP-2, HDMI-A-1. **No mux** — external connectors are wired to the dGPU, so an external display is physically NVIDIA-only; iGPU cannot drive externals; BIOS "Integrated" mode kills externals AND GPU compute.
- Standing GPU-role directive: NVIDIA only for local LLM; iGPU for displays/desktop.
- Probe outputs are long on this box → route to /tmp files and read back with read_file (see linux-system-audit Pitfalls).

## Probe chain (all read-only)
1. Topology: `ls -l /dev/dri/by-path/` (card0/1 <-> PCI), `cat /sys/class/drm/card0-*/status`, `cat /sys/class/drm/card0-*/modes` (the modes list is EDID-derived).
2. EDID: `dd if=/sys/class/drm/card0-<conn>/edid of=/tmp/x.edid bs=128 count=2` then `edid-decode /tmp/x.edid` (edid-decode ships in an Arch package; no parse-edid needed).
3. State: `kscreen-doctor -o` with `XDG_RUNTIME_DIR` + `WAYLAND_DISPLAY=wayland-0` set; journal: grep kwin/drm/EDID around the hotplug timestamp (`journalctl -b --no-pager`).
4. Driver alignment: `uname -r` vs `pacman -Q linux`; `lsmod | grep nvidia`; `nvidia-smi`; `pacman -Qu` (empty = fully updated).

## NVIDIA dummy/fallback EDID — the 640x480 signature
Signs: connected but ONLY 640x480 modes; EDID dump is 128 bytes; edid-decode shows Manufacturer **NVD** (NVIDIA's own PnP ID), Model 0, Year 1990, established timings 640x480 only, all detailed-timing descriptors EMPTY, checksum valid. This is NVIDIA's built-in fallback blob substituted because the monitor's real EDID never arrived over the link (cable/connector/dock DDC fault) — NOT a driver bug and NOT fixable in config. The fix is physical: reseat/replug the cable or power-cycle the monitor (direct cable beats a dock/dongle). Verify by re-dumping the EDID after the retest — a real monitor decodes with its own manufacturer and at least one detailed timing.

## NVIDIA 'Driver/library version mismatch' = reboot pending, not a broken install
nvidia-smi fails with `Failed to initialize NVML: Driver/library version mismatch` while userspace packages look fine → the running kernel still has an older nvidia module loaded in memory than the userspace libs on disk. Prove it: module version in memory (lsmod / boot journal) < installed `nvidia-open`; `uname -r` older than installed `linux`; `pacman -Qu` EMPTY; the installed kernel's modules exist (`ls /usr/lib/modules/<installed-ver>/extramodules/ | grep nvidia`) and `/boot/vmlinuz-linux` + initramfs were rebuilt. Everything on disk is consistent — the ONLY missing step is a reboot; do NOT reinstall or blacklist. Re-verify with nvidia-smi after boot.
- Same signature explains: CUDA/llama-server failing to initialize right after an update (identical NVML mismatch) and new displays connecting with the fallback blob — check reboot-pending before blaming anything else.
- Pitfall: `/sys/module/nvidia_drm/parameters/*` are 0400 root (Permission denied for the user) — read module facts from lsmod/journal/nvidia-smi, not those param files.
