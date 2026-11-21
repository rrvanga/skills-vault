# GeForce NOW on Linux (official NVIDIA Flatpak client)

Cloud streaming: no Proton, no local render. The bottleneck is network RTT/bandwidth + whether the host can *decode* the stream (NVDEC), not the GPU's 3D power.

## Correct source (verified 2026-10)
- Official native client: **NVIDIA's self-hosted Flatpak remote**, app id `com.nvidia.geforcenow`, branch `master` (~479 MB). NOT on Flathub: `com.nvidia.geforcenow` and `com.nvidia.GeForceNow` both return `{"detail":"App not found"}` there. Any web tutorial saying `flatpak install flathub com.nvidia.geforcenow` (or `...GeForceNow`) is wrong.
- Unofficial alternative: Flathub `io.github.hmlendea.geforcenow-electron` (GPL-3, unverified) / AUR `geforcenow-electron-bin` (prebuilt, current) or `geforcenow-electron` (source, often stale). Only fallback if the official client refuses to run.
- Older web claims of "Ubuntu 24.04 only" are wrong on Arch: the Flatpak runs here.

## Install
```bash
flatpak remote-add --if-not-exists GeForceNOW \
  https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo   # system scope
flatpak install --system -y --noninteractive GeForceNOW com.nvidia.geforcenow
```
`remote-add` + `install` at system scope trigger a **polkit password dialog** (KDE native) — the user types it, never the agent.

### Why not `--user` (this machine)
`flatpak install --user GeForceNOW com.nvidia.geforcenow` fails:
`error: The application com.nvidia.geforcenow/x86_64/master requires the runtime org.freedesktop.Platform/x86_64/24.08 which was not found`
Flatpak resolves a runtime/extension only from remotes in the **same installation scope**. Here `flathub` is system-scope, so a user-scope install cannot see it — and working around that by adding a user flathub duplicates the runtime *and* the ~958 MB `org.freedesktop.Platform.GL.nvidia-<ver>` extension. Match the scope of the existing flathub install (system). Check with `flatpak remotes --columns=name,url,scope`.

### Expected oddities (not errors)
- `Info: org.freedesktop.Platform is end-of-life ... 24.08 is no longer receiving fixes and security updates` — NVIDIA pins the EOL 24.08 runtime. Flathub still serves it. Security caveat: that runtime gets no fixes.
- The client reuses the existing `org.freedesktop.Platform.GL.nvidia-<driver>` extension (branch `1.4`) when the driver version matches the host module (e.g. host `615.78.08` → `nvidia-615-78-08`). Verify refs with `flatpak list --runtime | grep -E '24.08|nvidia'`.

## Prerequisite check (decoding)
GFN needs hardware video decode on the GPU it actually uses:
```bash
vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|apiVersion'
vulkaninfo 2>/dev/null | grep -E 'VK_KHR_video_decode_(h264|h265)'   # must appear for the dGPU
```
Reference host: GTX 1650 Max-Q exposes decode h264/h265/vp9 + encode h264/h265 (Vulkan Video, driver 615.78.8.0); the Intel UHD 630 exposes **none** — so the client must land on the NVIDIA GPU, and it does.

## Launch
Autostart from the KDE app menu needs nothing special (the Flatpak exports a .desktop entry). Launching it **from a Hermes gateway session** needs the desktop env passed explicitly, else it dies with no display:
```bash
env WAYLAND_DISPLAY=wayland-0 DISPLAY=:1 \
    XAUTHORITY=/run/user/1000/xauth_<rand> XDG_RUNTIME_DIR=/run/user/1000 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    flatpak run com.nvidia.geforcenow
```
Get the real values from `systemctl --user show-environment | grep -E 'WAYLAND|DISPLAY|XAUTH'` (the gateway service inherits the Plasma session env here; `xauth_<rand>` is randomised per session, so never hardcode it).

## Verify it actually came up (headless-proof)
```bash
pgrep -af 'cef/GeForceNOW'                                  # CEF processes (the client is Chromium Embedded Framework)
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv   # ./GeForceNOW holding VRAM = on the dGPU
fuser -v /dev/nvidia* 2>&1 | grep -i geforce                # dGPU device handles open
DISPLAY=:1 XAUTHORITY=<xauth> xwininfo -root -children | grep -i geforce   # window "GeForce NOW" = GUI really up
```
The client's own logs (best signal): `~/.var/app/com.nvidia.geforcenow/.local/state/NVIDIA/GeForceNOW/logs/NvContainer/GeForceNOWContainer.log` → `Container is started with 1. State: normal` plus `Transition to Started state for 'GfnBackgroundAgent' / 'GameStreamClientAgent'`.

### Benign noise (do not chase)
`debug.log` is full of `ERROR:raster_decoder.cc(1477) ... cmd: kDeleteTransferCacheEntryINTERNAL` — CEF transfer-cache churn, harmless, present in a healthy session.

## Network expectation
GFN wants <80 ms RTT and ~45 Mbps for 4K120. Probe before blaming the client:
```bash
ping -c 20 gfn.nvidia.com ; ping -c 20 play.geforcenow.com
curl -o /dev/null -w 'speed=%{speed_download} time=%{time_total}\n' https://speed.cloudflare.com/__down?bytes=50000000
```
Reference host: 3.8–5.6 ms RTT to NVIDIA edge, ~45.7 MB/s (~365 Mbps) down — comfortably above every GFN tier.

## Sandbox / blast radius
`flatpak info --show-permissions com.nvidia.geforcenow` shows **broad** grants: `filesystems=home` (whole home dir RW), `devices=all`, session + system bus, wayland+x11, pulseaudio. It's NVIDIA's own manifest, but it is not a tightly sandboxed app — treat it accordingly and don't leave it running unattended.

## Rollback
```bash
flatpak uninstall --system com.nvidia.geforcenow
flatpak remote-delete GeForceNOW
```
Also delete the user config if wanted: `~/.var/app/com.nvidia.geforcenow/`.
